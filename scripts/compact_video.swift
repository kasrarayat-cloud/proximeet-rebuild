// Proximeet — makes the compact walkthrough video on the Codemagic Mac (no ffmpeg there).
//
//     xcrun swift scripts/compact_video.swift <source.mp4> <target.mp4> [start-seconds]
//
// Re-encodes the simulator recording at half its pixel size with AVFoundation's export session,
// trimmed to the app itself: from the first dark frame (the app's black launch screen; the home
// screen before it is bright) to the last dark frame before the home screen returns. The app's
// screens are near-black, so frame brightness finds them without any timing. If no dark frame
// is found, `start-seconds` (the walkthrough test's own start marker) is used instead. The
// original recording is never modified. Exits non-zero on any failure; the caller then labels
// the fallback copy as such.
import AVFoundation
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: compact_video.swift <source> <target> [start]\n".utf8))
    exit(2)
}
let source = URL(fileURLWithPath: arguments[1])
let target = URL(fileURLWithPath: arguments[2])
let requestedStart = arguments.count > 3 ? max(0, Double(arguments[3]) ?? 0) : 0

let asset = AVURLAsset(url: source)
guard let track = asset.tracks(withMediaType: .video).first else {
    FileHandle.standardError.write(Data("no video track in \(source.path)\n".utf8))
    exit(3)
}
let natural = track.naturalSize.applying(track.preferredTransform)
let width = abs(natural.width), height = abs(natural.height)
// Half size, kept even for H.264.
let render = CGSize(width: (width / 4).rounded() * 2, height: (height / 4).rounded() * 2)

let duration = asset.duration

/// Mean brightness (0-255) of the frame nearest `seconds`, from a 24 × 24 downsample.
func brightness(at seconds: Double, generator: AVAssetImageGenerator) -> Double? {
    let time = CMTime(seconds: seconds, preferredTimescale: 600)
    guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
    let side = 24
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    let drawn: Bool = pixels.withUnsafeMutableBytes { bytes in
        guard let context = CGContext(
            data: bytes.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return true
    }
    guard drawn else { return nil }
    var sum = 0
    for index in stride(from: 0, to: pixels.count, by: 4) {
        sum += Int(pixels[index]) + Int(pixels[index + 1]) + Int(pixels[index + 2])
    }
    return Double(sum) / Double(side * side * 3)
}

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
// Measured on build 6ab71ced's recording: the home screen averages about 166, every app frame
// at most 60.5 (Welcome's hero), the app's black launch frame about 4.
let step = 0.25, dark = 100.0, total = duration.seconds
var samples: [(time: Double, isDark: Bool)] = []
var t = 0.0
while t < total {
    if let level = brightness(at: t, generator: generator) {
        samples.append((t, level < dark))
    }
    t += step
}
let firstDark = samples.first(where: { $0.isDark })?.time
let lastDark = samples.last(where: { $0.isDark })?.time
let startSeconds = firstDark.map { max(0, $0 - step) } ?? min(requestedStart, max(0, total - 1))
let endSeconds = lastDark.map { min(total, $0 + 2 * step) } ?? total
let start = CMTime(seconds: startSeconds, preferredTimescale: 600)
let end = endSeconds > startSeconds + 1 ? CMTime(seconds: endSeconds, preferredTimescale: 600) : duration

let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
layer.setTransform(
    track.preferredTransform.concatenating(CGAffineTransform(scaleX: render.width / width, y: render.height / height)),
    at: .zero
)
instruction.layerInstructions = [layer]
let composition = AVMutableVideoComposition()
composition.renderSize = render
composition.frameDuration = CMTime(value: 1, timescale: 30)
composition.instructions = [instruction]

try? FileManager.default.removeItem(at: target)
guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
    FileHandle.standardError.write(Data("no export session\n".utf8))
    exit(4)
}
export.outputURL = target
export.outputFileType = .mp4
export.videoComposition = composition
export.timeRange = CMTimeRange(start: start, end: end)
export.shouldOptimizeForNetworkUse = true

let finished = DispatchSemaphore(value: 0)
export.exportAsynchronously {
    finished.signal()
}
finished.wait()
guard export.status == .completed else {
    FileHandle.standardError.write(Data("export failed: \(String(describing: export.error))\n".utf8))
    exit(5)
}
print(String(
    format: "compact video: %.0f x %.0f, %.2f s to %.2f s of %.2f s (%@)",
    render.width, render.height, start.seconds, end.seconds, duration.seconds,
    firstDark == nil ? "start from the test's marker; no dark frame found" : "trimmed to the first and last app frames"
))

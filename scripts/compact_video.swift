// Proximeet — makes the compact walkthrough video on the Codemagic Mac (no ffmpeg there).
//
//     xcrun swift scripts/compact_video.swift <source.mp4> <target.mp4> [start-seconds]
//
// Re-encodes the simulator recording at half its pixel size from `start-seconds` (the moment
// the walkthrough test began, so the home screen and launch are trimmed) to the end, with
// AVFoundation's export session. The original recording is never modified. Exits non-zero on
// any failure; the caller then labels the fallback copy as such.
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
let start = CMTime(seconds: min(requestedStart, max(0, duration.seconds - 1)), preferredTimescale: 600)

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
export.timeRange = CMTimeRange(start: start, end: duration)
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
print(String(format: "compact video: %.0f x %.0f from %.2f s of %.2f s", render.width, render.height, start.seconds, duration.seconds))

#!/usr/bin/env python3
"""Offline analysis of a Welcome review run (docs/verification/welcome-mac-review.md).

Reads the artifacts that scripts/welcome_review.sh collects from a real iOS Simulator run and
measures them against the approved references. Standard library plus ffmpeg/ffprobe on PATH;
it runs on any machine with those tools (the VPS has them), never on the build itself.

  python3 scripts/analyze_welcome_review.py build/artifacts/welcome
  python3 scripts/analyze_welcome_review.py --self-test

What it measures, and what it cannot:
  * Motion: the hero region of each recorded frame is matched against the three original
    poses, composed on the page colour, to estimate where it sits on the path
    closed (0) -> opening (1) -> settled (2). From that it reports when each blend starts and
    ends, whether the blends are linear, and whether the settled pose ever regresses (a loop).
    simctl records a frame only when the screen changes, so a still hold has few frames:
    every time is a frame timestamp, with the recording's own resolution.
  * Reduce Motion: every recorded app frame should already be the settled pose.
  * Settled screenshot (440 x 956 point screens only): region-by-region difference from
    reference/welcome-settled.png, text ink bounding boxes (a Manrope-versus-system-font
    proxy) and colour samples. Figma's export and iOS rendering differ slightly, so the
    thresholds are review heuristics, not a pixel-perfect gate.
It cannot judge taste, VoiceOver, haptics, device frame rate or anything on a real iPhone.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "docs/design/welcome-approved/reference"
CATALOG = ROOT / "Proximeet/Resources/Assets.xcassets"
POSES = {
    "closed": CATALOG / "WelcomeClosed.imageset/welcome-closed.png",
    "opening": CATALOG / "WelcomeOpening.imageset/welcome-opening.png",
    "settled": CATALOG / "WelcomeSettled.imageset/welcome-settled.png",
}
GROUND = "0x050606"
CANVAS = (440, 956)  # points; the approved reference and the iPhone 17 Pro Max screen
N = 88               # hero comparison resolution (pixels per side)

# Approved regions in points (LAYOUT_SPEC.json). Text boxes, not ink.
REGIONS = {
    "brand": (32, 64, 236, 32),
    "hero": (0, 128, 440, 440),
    "headline": (32, 570, 376, 118),
    "supporting": (32, 704, 376, 25),
    "button": (32, 772, 376, 60),
    # Inside the button: the Apple mark's 22 x 26 box and the label's 187 x 26 box (+/- 3 pt).
    "apple_mark": (108, 786, 29, 32),
    "button_label": (138, 786, 194, 32),
    "more_options": (32, 844, 376, 44),
    "eligibility": (32, 913, 376, 16),
}
# Ink: light glyphs on the dark page, except the dark label inside the light button.
INK = {
    "brand": "light", "headline": "light", "supporting": "light", "button": "dark_inset",
    "apple_mark": "dark", "button_label": "dark", "more_options": "light", "eligibility": "light",
}
COLOUR_SAMPLES = {  # point rectangles expected to be flat colour
    "page_ground": ((8, 700, 16, 16), (0x05, 0x06, 0x06)),
    "button_fill": ((40, 776, 40, 8), (0xF6, 0xF7, 0xF2)),
    "presence_dot": ((34, 78, 4, 4), (0x38, 0xDB, 0xE5)),
}
REGION_TOLERANCE = 10.0   # mean absolute grey difference per region (0-255), heuristic
INK_TOLERANCE_PT = 3.0    # ink bounding-box edge difference in points, heuristic
COLOUR_TOLERANCE = 12     # per channel, heuristic (simulator colour management may shift)


# --------------------------------------------------------------------------------------
# ffmpeg helpers
# --------------------------------------------------------------------------------------

def require_tools() -> None:
    missing = [tool for tool in ("ffmpeg", "ffprobe") if shutil.which(tool) is None]
    if missing:
        sys.exit(f"analyze_welcome_review: missing {', '.join(missing)} on PATH")


def run(args: list[str]) -> bytes:
    result = subprocess.run(args, capture_output=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"{args[0]} failed ({result.returncode}): "
                           f"{result.stderr.decode('utf-8', 'replace').strip()[:400]}")
    return result.stdout


def media_size(path: Path) -> tuple[int, int]:
    out = run(["ffprobe", "-v", "error", "-select_streams", "v:0",
               "-show_entries", "stream=width,height", "-of", "csv=p=0", str(path)])
    width, height = out.decode().strip().splitlines()[0].split(",")[:2]
    return int(width), int(height)


def frame_times(path: Path) -> list[float]:
    out = run(["ffprobe", "-v", "error", "-select_streams", "v:0",
               "-show_entries", "frame=best_effort_timestamp_time", "-of", "csv=p=0", str(path)])
    times = []
    for line in out.decode().split():
        value = line.strip().strip(",")
        if value and value != "N/A":
            times.append(float(value))
    return times


def crop_filter(rect_px: tuple[int, int, int, int], size: tuple[int, int], fmt: str) -> str:
    x, y, w, h = rect_px
    return f"crop={w}:{h}:{x}:{y},scale={size[0]}:{size[1]}:flags=area,format={fmt}"


def raw_frames(path: Path, rect_px, size, fmt: str = "gray", video: bool = True) -> list[bytes]:
    channels = 3 if fmt == "rgb24" else 1
    args = ["ffmpeg", "-v", "error", "-i", str(path), "-vf", crop_filter(rect_px, size, fmt)]
    if video:
        args += ["-fps_mode", "passthrough"]
    else:
        args += ["-frames:v", "1"]
    data = run(args + ["-f", "rawvideo", "-pix_fmt", fmt, "-"])
    step = size[0] * size[1] * channels
    return [data[i:i + step] for i in range(0, len(data) - step + 1, step)]


def pose_reference(name: str, size: int = N) -> bytes:
    """The original RGBA pose, fitted to a square and composed on the page colour."""
    data = run([
        "ffmpeg", "-v", "error",
        "-f", "lavfi", "-i", f"color=c={GROUND}:s={size}x{size}:d=1",
        "-i", str(POSES[name]),
        "-filter_complex", f"[1:v]scale={size}:{size}:flags=area,format=rgba[p];"
                           f"[0:v][p]overlay=format=auto,format=gray",
        "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "gray", "-",
    ])
    return data[:size * size]


# --------------------------------------------------------------------------------------
# Geometry
# --------------------------------------------------------------------------------------

def to_px(rect_pt, scale: float) -> tuple[int, int, int, int]:
    x, y, w, h = rect_pt
    return (round(x * scale), round(y * scale), max(1, round(w * scale)), max(1, round(h * scale)))


def canvas_scale(width_px: int, height_px: int) -> float | None:
    """Pixels per point, only for an exact 440 x 956 point capture at 1x, 2x or 3x.

    Other iPhones have nearly the same aspect ratio but a different layout in points, so a
    proportional match would compare the wrong pixels; they use the XCTest geometry instead.
    """
    for s in (1, 2, 3):
        if (width_px, height_px) == (CANVAS[0] * s, CANVAS[1] * s):
            return float(s)
    return None


def geometry_rects(geometry: dict) -> tuple[tuple, tuple, float] | None:
    """(hero_pt, button_pt, window_width) recovered from XCTest geometry (see WelcomeStack)."""
    try:
        window = geometry["window"]
        elements = geometry["elements"]
        brand_mid = elements["brand"]["midY"]
        headline_top = elements["headline"]["minY"]
        button = elements["continueWithApple"]
        button_pt = (button["minX"], button["minY"], button["width"], button["height"])
    except (KeyError, TypeError):
        return None
    top = brand_mid + 16 + 32          # brand row bottom (row is 32 pt at default size) + gap
    slot = headline_top - 2 - top
    side = min(window["width"], max(slot, 140))
    if side <= 0:
        return None
    hero_pt = ((window["width"] - side) / 2, top + (slot - side) / 2, side, side)
    return hero_pt, button_pt, float(window["width"])


# --------------------------------------------------------------------------------------
# Motion
# --------------------------------------------------------------------------------------

RESIDUAL_LIMIT = 20.0      # RMS grey error above which a hero crop is not one of the poses
BLEND1 = (0.30, 0.60)      # closed -> opening, approved 0.45 s
BLEND2 = (0.40, 0.70)      # opening -> settled, approved 0.55 s
LINEAR_MAX_DEVIATION = 0.05  # max |phase - straight-line fit| within a blend (eased blends ~0.06-0.08)
MIN_BLEND_FRAMES = 3


def _dot(a, b) -> float:
    return float(sum(x * y for x, y in zip(a, b)))


def pose_phase(frame: bytes, refs: dict[str, bytes]) -> tuple[float, float]:
    """(phase, residual): 0 closed, 1 opening, 2 settled; residual is RMS grey error."""
    f = list(frame)
    c, o, s = (list(refs[k]) for k in ("closed", "opening", "settled"))
    best = None
    for base, target, offset in ((c, o, 0.0), (o, s, 1.0)):
        d = [t - b for t, b in zip(target, base)]
        denom = _dot(d, d) or 1.0
        alpha = max(0.0, min(1.0, _dot([x - b for x, b in zip(f, base)], d) / denom))
        residual = math.sqrt(sum((x - (b + alpha * dd)) ** 2 for x, b, dd in zip(f, base, d)) / len(f))
        if best is None or residual < best[1]:
            best = (offset + alpha, residual)
    return best


def app_visible(button_frame: bytes) -> bool:
    return sum(button_frame) / len(button_frame) > 200  # #F6F7F2 fill is ~246 grey


def max_linear_deviation(points: list[tuple[float, float]]) -> float | None:
    """Largest distance of a blend's phases from their least-squares straight line."""
    if len(points) < MIN_BLEND_FRAMES:
        return None
    n = len(points)
    mx = sum(p[0] for p in points) / n
    my = sum(p[1] for p in points) / n
    sxx = sum((p[0] - mx) ** 2 for p in points)
    if sxx == 0:
        return None
    slope = sum((p[0] - mx) * (p[1] - my) for p in points) / sxx
    return max(abs(p[1] - (my + slope * (p[0] - mx))) for p in points)


def launch_samples(video: Path, hero_pt, button_pt, scale: float, refs) -> list[dict]:
    """Frames from the launch on: the recording opens on the home screen (the previous app
    instance was terminated), so everything before the first non-app frame is discarded."""
    times = frame_times(video)
    hero = raw_frames(video, to_px(hero_pt, scale), (N, N))
    buttons = raw_frames(video, to_px(button_pt, scale), (32, 8)) if button_pt else None
    if len(times) != len(hero):
        raise RuntimeError(f"{video.name}: {len(times)} timestamps for {len(hero)} frames; "
                           "refusing to invent a frame clock")
    samples = []
    for index, frame in enumerate(hero):
        phase, residual = pose_phase(frame, refs)
        samples.append({"t": round(times[index], 4),
                        "visible": app_visible(buttons[index]) if buttons else True,
                        "phase": round(phase, 3), "residual": round(residual, 2)})
    hidden = next((i for i, s in enumerate(samples) if not s["visible"]), None)
    return samples[hidden:] if hidden is not None else samples


def analyse_motion(video: Path, hero_pt, button_pt, scale: float, refs: dict[str, bytes]) -> dict:
    samples = launch_samples(video, hero_pt, button_pt, scale, refs)
    shown = [s for s in samples if s["visible"]]
    if not shown:
        return {"frames": len(samples), "verdict": "NO_APP_FRAMES"}
    t0 = shown[0]["t"]
    rel = [dict(s, t=round(s["t"] - t0, 4)) for s in shown]
    non_pose = [s for s in rel if s["residual"] > RESIDUAL_LIMIT]

    def first(predicate):
        return next((s["t"] for s in rel if predicate(s)), None)

    blend_start = first(lambda s: s["phase"] > 0.05)
    opening = first(lambda s: s["phase"] >= 0.95)
    settled = first(lambda s: s["phase"] >= 1.95)
    after = [s["phase"] for s in rel if settled is not None and s["t"] >= settled]
    regressed = bool(after) and min(after) < 1.85
    before = [s["phase"] for s in rel if settled is None or s["t"] <= settled]
    monotonic = all(b >= a - 0.05 for a, b in zip(before, before[1:]))
    seg1 = [(s["t"], s["phase"]) for s in rel if 0.05 < s["phase"] < 0.95]
    seg2 = [(s["t"], s["phase"]) for s in rel if 1.05 < s["phase"] < 1.95]
    blend1 = None if blend_start is None or opening is None else round(opening - blend_start, 4)
    blend2 = None if opening is None or settled is None else round(settled - opening, 4)
    dev1, dev2 = max_linear_deviation(seg1), max_linear_deviation(seg2)
    result = {
        "frames_from_launch": len(samples), "app_frames": len(rel),
        "first_app_frame_s": t0, "first_app_frame_phase": rel[0]["phase"],
        "closed_hold_observed_s": blend_start,
        "blend_to_opening_first_frame_s": blend_start, "opening_reached_s": opening,
        "settled_reached_s": settled,
        "blend_durations_s": {"closed_to_opening": blend1, "opening_to_settled": blend2},
        "blend_frames": {"closed_to_opening": len(seg1), "opening_to_settled": len(seg2)},
        "linear_max_deviation": {"closed_to_opening": dev1, "opening_to_settled": dev2},
        "monotonic_until_settled": monotonic, "ends_settled": rel[-1]["phase"] >= 1.95,
        "regressed_after_settled": regressed, "non_pose_frames": len(non_pose),
        "max_residual": max(s["residual"] for s in rel),
        "expected": "closed hold ~0.40 s (partly hidden by the launch animation), linear blend to "
                    "opening over ~0.45 s, linear blend to settled over ~0.55 s, then hold; never regress",
        "samples": rel,
    }
    if len(seg1) < MIN_BLEND_FRAMES or len(seg2) < MIN_BLEND_FRAMES:
        result["verdict"] = "INSUFFICIENT_FRAMES"  # a cut, a skipped pose, or too few recorded frames
        return result
    checks = [
        rel[0]["phase"] < 0.5,                     # the sequence was seen from (near) closed
        monotonic, result["ends_settled"], not regressed, not non_pose,
        blend1 is not None and BLEND1[0] <= blend1 <= BLEND1[1],
        blend2 is not None and BLEND2[0] <= blend2 <= BLEND2[1],
        dev1 is not None and dev1 <= LINEAR_MAX_DEVIATION,
        dev2 is not None and dev2 <= LINEAR_MAX_DEVIATION,
    ]
    result["verdict"] = "CONSISTENT" if all(checks) else "REVIEW"
    return result


def analyse_reduce_motion(video: Path, hero_pt, button_pt, scale: float, refs: dict[str, bytes]) -> dict:
    samples = [s for s in launch_samples(video, hero_pt, button_pt, scale, refs) if s["visible"]]
    settled = bool(samples) and all(s["phase"] >= 1.9 and s["residual"] <= RESIDUAL_LIMIT for s in samples)
    return {"app_frames": len(samples),
            "settled_from_first_app_frame": settled,
            "min_phase": min((s["phase"] for s in samples), default=None),
            "max_residual": max((s["residual"] for s in samples), default=None),
            "verdict": "CONSISTENT" if settled else ("NO_APP_FRAMES" if not samples else "REVIEW")}


# --------------------------------------------------------------------------------------
# Screenshots
# --------------------------------------------------------------------------------------

def downscale(path: Path, size, fmt: str = "gray") -> bytes:
    w, h = media_size(path)
    return raw_frames(path, (0, 0, w, h), size, fmt=fmt, video=False)[0]


def region_bytes(image: bytes, width: int, rect, channels: int = 1) -> list[int]:
    x, y, w, h = rect
    out = []
    for row in range(y, y + h):
        start = (row * width + x) * channels
        out.extend(image[start:start + w * channels])
    return out


def ink_bbox(image: bytes, width: int, rect, mode: str):
    x0, y0, w, h = rect
    xs, ys = [], []
    for row in range(y0, y0 + h):
        for col in range(x0, x0 + w):
            v = image[row * width + col]
            if (v > 128) if mode == "light" else (v < 110):  # "dark" and "dark_inset"
                xs.append(col)
                ys.append(row)
    if mode == "dark_inset":  # keep the mark and label ink, not the fill's rounded corners
        pairs = [(a, b) for a, b in zip(xs, ys) if x0 + 12 <= a < x0 + w - 12 and y0 + 4 <= b < y0 + h - 4]
        xs, ys = [p[0] for p in pairs], [p[1] for p in pairs]
    if not xs:
        return None
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def analyse_settled_screenshot(shot: Path, refs: dict[str, bytes], scale_hint=None) -> dict:
    width_px, height_px = media_size(shot)
    scale = canvas_scale(width_px, height_px)
    result = {"file": shot.name, "pixels": [width_px, height_px]}
    if scale is None:
        result["verdict"] = "NOT_REFERENCE_CANVAS"
        result["note"] = "Not a 440 x 956 point capture; compare by eye with the reference."
        return result
    result["points_per_pixel_scale"] = scale
    reference = REFERENCE / "welcome-settled.png"
    ours = downscale(shot, CANVAS)
    theirs = downscale(reference, CANVAS)
    regions = {}
    for name, rect in REGIONS.items():
        a = region_bytes(ours, CANVAS[0], rect)
        b = region_bytes(theirs, CANVAS[0], rect)
        diff = sum(abs(p - q) for p, q in zip(a, b)) / len(a)
        entry = {"mean_abs_diff": round(diff, 2), "within_tolerance": diff <= REGION_TOLERANCE}
        if name in INK:
            ib_ours, ib_ref = ink_bbox(ours, CANVAS[0], rect, INK[name]), ink_bbox(theirs, CANVAS[0], rect, INK[name])
            entry["ink_bbox_pt"] = ib_ours
            entry["reference_ink_bbox_pt"] = ib_ref
            if ib_ours and ib_ref:
                deltas = [abs(p - q) for p, q in zip(ib_ours, ib_ref)]
                entry["ink_max_edge_delta_pt"] = max(deltas)
                entry["ink_within_tolerance"] = max(deltas) <= INK_TOLERANCE_PT
        regions[name] = entry
    hero_small = raw_frames(shot, to_px(REGIONS["hero"], scale), (N, N), video=False)[0]
    phase, residual = pose_phase(hero_small, refs)
    colours = {}
    rgb = downscale(shot, CANVAS, fmt="rgb24")
    for name, (rect, expected) in COLOUR_SAMPLES.items():
        px = region_bytes(rgb, CANVAS[0], rect, channels=3)
        mean = tuple(round(sum(px[i::3]) / (len(px) // 3)) for i in range(3))
        colours[name] = {"mean_rgb": mean, "expected_rgb": expected,
                         "within_tolerance": all(abs(m - e) <= COLOUR_TOLERANCE for m, e in zip(mean, expected))}
    result.update({"regions": regions, "hero_phase": round(phase, 3), "hero_residual": round(residual, 2),
                   "colours": colours})
    checks = [r["within_tolerance"] for r in regions.values()] + \
             [r.get("ink_within_tolerance", True) for r in regions.values()] + \
             [c["within_tolerance"] for c in colours.values()] + [phase >= 1.9 and residual <= RESIDUAL_LIMIT]
    result["verdict"] = "CONSISTENT" if all(checks) else "REVIEW"
    return result


# --------------------------------------------------------------------------------------
# Entry points
# --------------------------------------------------------------------------------------

SCREENSHOTS = (
    ("settled_screenshot", "01-welcome-settled.png"),
    # Taken seconds after a Reduce Motion preview launch: a layout check only. The Reduce Motion
    # evidence is the recording (reduce_motion_video) and the XCTest first-look capture.
    ("preview_flag_settled_layout", "02-welcome-preview-flag-settled-layout.png"),
)


def analyse(artifacts: Path) -> dict:
    require_tools()
    refs = {name: pose_reference(name) for name in POSES}
    report: dict = {"artifacts": str(artifacts), "tolerances": {
        "region_mean_abs_diff": REGION_TOLERANCE, "ink_edge_pt": INK_TOLERANCE_PT,
        "colour_channel": COLOUR_TOLERANCE, "pose_residual": RESIDUAL_LIMIT,
        "blend_s": {"closed_to_opening": BLEND1, "opening_to_settled": BLEND2},
        "linear_max_deviation": LINEAR_MAX_DEVIATION}}
    geometry_file = artifacts / "geometry-default.json"
    geometry = json.loads(geometry_file.read_text()) if geometry_file.is_file() else None
    report["geometry_from_xctest"] = geometry

    for key, name in (("motion", "welcome-motion.mp4"), ("reduce_motion_video", "welcome-reduce-motion.mp4")):
        video = artifacts / name
        if not video.is_file():
            report[key] = {"verdict": "MISSING", "file": name}
            continue
        w, h = media_size(video)
        scale = canvas_scale(w, h)
        if scale:
            hero, button = REGIONS["hero"], REGIONS["button"]
        elif geometry and geometry_rects(geometry):
            hero, button, window_width = geometry_rects(geometry)
            scale = w / window_width
        else:
            report[key] = {"verdict": "UNKNOWN_GEOMETRY", "file": name,
                           "note": "not a 440 x 956 capture and no usable geometry-default.json"}
            continue
        try:
            analysed = analyse_motion(video, hero, button, scale, refs) if key == "motion" \
                else analyse_reduce_motion(video, hero, button, scale, refs)
        except RuntimeError as error:
            analysed = {"verdict": "UNREADABLE", "error": str(error)}
        report[key] = dict(analysed, file=name)

    for key, name in SCREENSHOTS:
        shot = artifacts / name
        report[key] = analyse_settled_screenshot(shot, refs) if shot.is_file() else {"verdict": "MISSING", "file": name}
    return report


def write_report(report: dict, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "welcome-review-analysis.json").write_text(json.dumps(report, indent=1, default=list) + "\n")
    lines = ["Welcome review analysis (heuristic; see docs/verification/welcome-mac-review.md)", ""]
    for key in ("motion", "reduce_motion_video") + tuple(k for k, _ in SCREENSHOTS):
        entry = report.get(key, {})
        lines.append(f"{key}: {entry.get('verdict')}")
        if key == "motion" and "samples" in entry:
            for field in ("first_app_frame_phase", "closed_hold_observed_s", "blend_durations_s",
                          "blend_frames", "linear_max_deviation", "monotonic_until_settled",
                          "ends_settled", "regressed_after_settled", "non_pose_frames", "max_residual"):
                lines.append(f"  {field}: {entry.get(field)}")
        if key == "reduce_motion_video":
            for field in ("app_frames", "min_phase", "max_residual"):
                lines.append(f"  {field}: {entry.get(field)}")
        if "regions" in entry:
            for name, region in entry["regions"].items():
                lines.append(f"  {name}: diff {region['mean_abs_diff']}"
                             + (f", ink delta {region.get('ink_max_edge_delta_pt')} pt" if "ink_max_edge_delta_pt" in region else ""))
            lines.append(f"  hero phase {entry['hero_phase']} (2 = settled), residual {entry['hero_residual']}")
            for name, colour in entry["colours"].items():
                lines.append(f"  {name}: {colour['mean_rgb']} vs {colour['expected_rgb']}")
    (out_dir / "welcome-review-analysis.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


# --------------------------------------------------------------------------------------
# Self-test on the approved references (no simulator involved)
# --------------------------------------------------------------------------------------

HOME_SCREEN = "0x2A3B4C"  # stand-in for the springboard between app instances


def _still(video: Path, seconds: float, out: Path) -> None:
    run(["ffmpeg", "-v", "error", "-ss", f"{seconds:.3f}", "-i", str(video), "-frames:v", "1", str(out)])


def _clip(parts: list[tuple[str, object, float]], out: Path) -> None:
    """Concatenate still images, a home-screen colour and videos, at 30 fps, into a 3x movie."""
    args, chains = ["ffmpeg", "-v", "error", "-y"], []
    for index, (kind, source, seconds) in enumerate(parts):
        if kind == "still":
            args += ["-loop", "1", "-framerate", "30", "-t", f"{seconds}", "-i", str(source)]
        elif kind == "home":
            args += ["-f", "lavfi", "-t", f"{seconds}", "-i", f"color=c={HOME_SCREEN}:s=440x956:r=30"]
        else:
            args += ["-i", str(source)]
        chains.append(f"[{index}:v]scale=440:956,setsar=1,fps=30,format=yuv420p[v{index}]")
    joined = "".join(f"[v{i}]" for i in range(len(parts)))
    graph = ";".join(chains) + f";{joined}concat=n={len(parts)}:v=1:a=0[c];[c]scale=1320:2868:flags=lanczos[out]"
    run(args + ["-filter_complex", graph, "-map", "[out]", "-c:v", "libx264", "-crf", "18",
                "-pix_fmt", "yuv420p", str(out)])


def _eased_study(closed: Path, opening: Path, settled: Path, out: Path) -> None:
    """The approved timing with smoothstep easing instead of linear blends (a wrong build)."""
    ease = "st(0,clip((T-{a})/{d},0,1));st(1,ld(0)*ld(0)*(3-2*ld(0)));A*(1-ld(1))+B*ld(1)"
    graph = (f"[0:v]format=yuv420p[c];[1:v]format=yuv420p[o];[2:v]format=yuv420p[s];"
             f"[c][o]blend=all_expr='{ease.format(a=0.4, d=0.45)}'[x];"
             f"[x][s]blend=all_expr='{ease.format(a=0.85, d=0.55)}'[y]")
    args = ["ffmpeg", "-v", "error", "-y"]
    for still in (closed, opening, settled):
        args += ["-loop", "1", "-framerate", "30", "-t", "4", "-i", str(still)]
    run(args + ["-filter_complex", graph, "-map", "[y]", "-c:v", "libx264", "-crf", "18",
                "-pix_fmt", "yuv420p", str(out)])


def self_test() -> int:
    require_tools()
    study = REFERENCE / "welcome-motion-study.mp4"
    results: dict[str, bool] = {}
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        stills = {name: work / f"{name}.png" for name in ("closed", "opening", "settled")}
        _still(study, 0.0, stills["closed"])
        _still(study, 26 / 30, stills["opening"])
        _still(study, 3.9, stills["settled"])
        reference_3x = work / "reference-3x.png"
        run(["ffmpeg", "-v", "error", "-i", str(REFERENCE / "welcome-settled.png"),
             "-vf", "scale=1320:2868:flags=lanczos", str(reference_3x)])
        closed_3x = work / "closed-3x.png"
        run(["ffmpeg", "-v", "error", "-i", str(stills["closed"]), "-vf", "scale=1320:2868:flags=lanczos",
             str(closed_3x)])

        # 1. A correct run as welcome_review.sh records it: a stale frame of the previous
        #    instance, the home screen, then the launch and the study; Reduce Motion likewise.
        good = work / "good"
        good.mkdir()
        _clip([("still", stills["settled"], 0.3), ("home", None, 0.5), ("video", study, 4.0)], good / "welcome-motion.mp4")
        _clip([("still", stills["settled"], 0.3), ("home", None, 0.5), ("still", stills["settled"], 2.0)],
              good / "welcome-reduce-motion.mp4")
        for name in ("01-welcome-settled.png", "02-welcome-preview-flag-settled-layout.png"):
            (good / name).write_bytes(reference_3x.read_bytes())
        report = analyse(good)
        motion = report["motion"]
        durations = motion.get("blend_durations_s", {})
        results["correct run: motion CONSISTENT"] = motion["verdict"] == "CONSISTENT"
        results["correct run: blends ~0.45 s and ~0.55 s"] = \
            0.38 <= (durations.get("closed_to_opening") or -1) <= 0.50 and \
            0.50 <= (durations.get("opening_to_settled") or -1) <= 0.62
        results["correct run: stale leading frame ignored"] = motion.get("first_app_frame_phase", 9) < 0.1
        results["correct run: Reduce Motion CONSISTENT"] = report["reduce_motion_video"]["verdict"] == "CONSISTENT"
        results["correct run: settled screenshot CONSISTENT"] = report["settled_screenshot"]["verdict"] == "CONSISTENT"
        print(json.dumps({k: motion.get(k) for k in ("blend_durations_s", "blend_frames", "linear_max_deviation",
                                                     "max_residual")}))

        # 2. Wrong builds: a hard cut with no opening pose, Reduce Motion that animates anyway,
        #    and the closed pose where the settled screen belongs.
        bad = work / "bad"
        bad.mkdir()
        _clip([("home", None, 0.5), ("still", stills["closed"], 1.4), ("still", stills["settled"], 2.0)],
              bad / "welcome-motion.mp4")
        _clip([("home", None, 0.5), ("video", study, 4.0)], bad / "welcome-reduce-motion.mp4")
        (bad / "01-welcome-settled.png").write_bytes(closed_3x.read_bytes())
        report = analyse(bad)
        results["hard cut: not CONSISTENT"] = report["motion"]["verdict"] in ("INSUFFICIENT_FRAMES", "REVIEW")
        results["animating Reduce Motion: REVIEW"] = report["reduce_motion_video"]["verdict"] == "REVIEW"
        results["closed-pose screenshot: REVIEW"] = report["settled_screenshot"]["verdict"] == "REVIEW" \
            and report["settled_screenshot"]["hero_phase"] < 0.5

        # 3. Eased instead of linear blends, with the approved timing.
        eased = work / "eased"
        eased.mkdir()
        _eased_study(stills["closed"], stills["opening"], stills["settled"], work / "eased-1x.mp4")
        _clip([("home", None, 0.5), ("video", work / "eased-1x.mp4", 4.0)], eased / "welcome-motion.mp4")
        report = analyse(eased)
        deviations = report["motion"].get("linear_max_deviation", {})
        results["eased blends: REVIEW"] = report["motion"]["verdict"] == "REVIEW" and \
            any((d or 0) > LINEAR_MAX_DEVIATION for d in deviations.values())
        print(json.dumps({"eased": {k: report["motion"].get(k) for k in ("blend_durations_s", "linear_max_deviation")}}))
    for name, ok in results.items():
        print(("PASS " if ok else "FAIL ") + name)
    return 0 if all(results.values()) else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("artifacts", nargs="?", type=Path, help="welcome artifact directory from the run")
    parser.add_argument("--out", type=Path, help="where to write the report (default: the artifact directory)")
    parser.add_argument("--self-test", action="store_true", help="check the analysis against the references")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    if args.artifacts is None or not args.artifacts.is_dir():
        parser.error("give the welcome artifact directory, or --self-test")
    report = analyse(args.artifacts)
    write_report(report, args.out or args.artifacts)
    return 0


if __name__ == "__main__":
    sys.exit(main())

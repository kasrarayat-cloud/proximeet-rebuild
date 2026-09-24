# Proximeet — editable band and signal proof

This package contains a real Blender scene and a rendered attachment study. It is a design prototype, not an iPhone recording or a completed app redesign.

## What is editable

- A hollow cyan band with separate interlaced outer yarn, inner yarn and bound edges.
- The silver signal plate, retaining hardware, graphite rear clasp and chat engraving.
- Material settings, studio lights, camera and rigid plate animation.
- The procedural Python generator; no external textures, fonts or downloaded models are required.

The scene uses millimetre coordinates with Blender's unit scale set to 0.001. Its timeline is frames 1–120 at 24 fps. Frame 100 is the mounted inspection pose. The movie presents the plate approaching its mount, settling and holding for inspection.

## Files

- `proximeet-signature-proof.blend`: editable source scene.
- `build_signature.py`: deterministic scene generator.
- `render_scene.py`: render selected frames using the verified RTX 5070 OptiX device.
- `encode_motion.py`: encode all 120 PNG frames using Blender's bundled FFmpeg.
- `manifest.json`: scope and rendering metadata.
- `README.md`: this handoff.

The motion MP4 is delivered separately. The full PNG sequence remains in the Proximeet working folder on the Windows PC.

## Reproduce on the configured Windows PC

Blender 4.5.14 LTS is installed at:

`C:\Users\Kasra\AppData\Local\ProximeetTools\blender-4.5.14-windows-x64\blender.exe`

Build a source scene and render the mounted pose:

```text
blender --background --factory-startup --python-exit-code 1 --python build_signature.py -- --out output --resolution 900 --samples 64 --render-frame 100
```

Render and encode the motion:

```text
blender --background output/proximeet-signature-proof.blend --python-exit-code 1 --python render_scene.py -- --out frames --frames 1:120 --resolution 900 --samples 48
blender --background --factory-startup --python-exit-code 1 --python encode_motion.py -- --frames frames --out proximeet-band-motion.mp4
```

Use the full Blender executable path if `blender` is not on PATH. Both rendering scripts deliberately require the configured RTX 5070 OptiX device rather than silently switching to CPU rendering. The geometry generator can save its scene without a GPU when `--render-frame` is omitted.

## Before native iPhone integration

The detailed textile is an authoring mesh. Make a separate mobile mesh and bake the fine yarn geometry into UV-mapped normal and roughness maps; preserve the visible silhouette, plate bevels and hardware. The procedural Cycles materials and lighting need reconstruction or baking for the native renderer. The editable scene is the fidelity source; no mobile-ready USDZ is claimed here.

Keep intent, signal selection and confirmation in SwiftUI. Drive the plate's rigid movement from application state, allow interruption and reselection, and provide a reduced-motion alternative. The five-second review movie includes inspection time; it is not a required delay for selecting a signal.

On the actual iPhone 17 Pro Max, verify material appearance, texture shimmer, repeated selections, offline loading, accessibility and sustained frame pacing. Windows GPU rendering establishes none of those device results. No new SwiftUI build, TestFlight upload, Apple signing operation or cloud Mac run is part of this asset proof.

## Authorship and provenance

The working scene and refinements were authored by Codex. Actual Claude Opus 5.5 was attempted first at ultracode effort and then at high effort; neither run produced source. Both were stopped, and their logs remain separately preserved on the VPS. This package does not attribute Codex work to Opus.

The owner's supplied visual reference guided the proportions, cyan textile, brushed metal and central plate placement. This is an initial editable proof for review, not a claim that the entire showcase or finished product has been reproduced.

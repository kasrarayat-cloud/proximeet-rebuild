# Signature band — editable 3D proof

Date: 24 September 2026. This is a separate material and motion prototype, not a native iPhone implementation or a completed app redesign.

## Current evidence

The lead ran the working v4 scene on the owner's Windows render station: Blender 4.5.14 LTS and an NVIDIA GeForce RTX 5070 using OptiX. The mounted hero at frame 100 rendered at **900 × 900, 64 samples, exit 0** and was visually inspected. The chat engraving was corrected with actual Boolean geometry before this successful render.

The full motion render and H.264 encoding both completed with exit 0 on Windows (combined process runtime 264.50 seconds). Independent ffprobe decoding verified **120 frames, 900 × 900, 24 fps, exactly 5.000 seconds**. The lead inspected frames 1, 25, 49, 73, 97 and 120: plate inspection, approach, attachment and final hold render cleanly. The movie uses 48 samples per frame. This is approval for delivering a prototype motion proof, not final founder approval or native device validation.

The generator, rendering helper, encoder and README were copied unchanged from the lead's local working directory into `assets/three_d/` in the active cloud clone. All four destination byte counts and SHA-256 hashes match the source. No Blender execution or render occurred on the VPS.

## Source and editable scene

The geometry is a real hollow cyan band with separate woven surfaces, a central silver plate, retaining hardware, rear clasp and recessed chat icon. Materials, camera, lights and the rigid plate animation remain editable. The scene uses millimetre coordinates with Blender unit scale 0.001; its timeline is frames 1–120 at 24 fps and frame 100 is the mounted inspection pose.

This is a detailed authoring mesh. A separate mobile mesh, texture baking or material reconstruction, native interaction integration and actual-device testing remain necessary. No mobile-ready USDZ, native rendering performance, accessibility behavior or TestFlight readiness is claimed. The editable `.blend` and reviewed media are separate deliverables; this repository change preserves their reproducible source.

| File in `assets/three_d/` | Bytes | SHA-256 |
|---|---:|---|
| `build_signature.py` | 21221 | `ea4e5202979810c713a6b1ff4bae573beb566dcc026740836378b6c984eb78f2` |
| `render_scene.py` | 2128 | `49fe98334f73ed7f0fcea214453122d469b87351c95003b5ec0bbc9bc7ba9bf8` |
| `encode_motion.py` | 1956 | `3b3646abc8ccc63b025ab695614015e32309a4ceb25979849a555da9910b8475` |
| `README.md` | 3963 | `20d63a9ea22eaefc7bb01c1bf102d42b8302071a31158052012ff0c5b3a93415` |

## Authorship and stopped attempts

**Codex authored the working source and refinements.** Actual Claude Code Opus 5.5 was attempted first with ultracode effort (PID 145181). It reached its output-token limit without producing source, began another reasoning cycle and was stopped with a guarded SIGTERM. A smaller recovery used the same model with high effort, ordinary permissions and a session-only empty MCP configuration (PID 209890); it also produced no source and was stopped after more than nine minutes. Neither attempt receives authorship credit for the working generator.

Both processes were confirmed ended. Their separate prompts, JSONL logs, stderr and stop records remain private and Git-ignored under `.claude-run/signature-3d*`. No permission, trust, account or persistent configuration setting was changed.

The owner's supplied visual reference guided the cyan textile, silver plate and proportions. No external model, image texture or downloaded font is needed by the generator. Reproduction commands and editable object roles are documented in [the source README](../../assets/three_d/README.md).

## Boundary and next evidence

This pass changes only the 3D source package and documentation. The SwiftUI app and its verified Codemagic build 2 at `0f21dea` remain unchanged; the earlier 53 Mac tests and native screenshots describe that app revision, not this Blender scene. No new cloud build, Apple operation, deployment or legacy-repository change occurred. Original code and recovery material remain preserved.

The separately delivered artifacts were transferred from Windows and verified byte-for-byte by SHA-256:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `proximeet-band-motion.mp4` | 910358 | `6f94b98af4645cc922fb873772f056090e4fabf7af986a56ef610ddee43386e4` |
| `proximeet-signature-proof.blend` | 26147024 | `60b6ee6c79f2f2b2e26de437d05a38ee7de5b29047071ba4a101f56856e79d79` |

Windows source folder: `C:\Users\Kasra\Documents\Proximeet\signature-3d\`; the editable scene is under `v4/`, and all 120 PNG frames remain under `frames-final/`. The rendering helper resolves the plate modifiers once in memory before animating; the saved source retains its editable engraving. Source preservation and the reviewed movie do not establish final founder approval.

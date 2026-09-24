# Task 01 Figma implementation references

Read-only retrieval from Figma file `yUPcuFY2ZJpTqyPpu7blen` on 2026-09-24. Frames were discovered through page metadata, not guessed: page `0:1`, B1 `4:187`, B2 `4:316`. Both are 393 × 852. These are intermediate source references, not production artwork or evidence of an iOS build.

## Files

- `b1-screenshot.png`, `b2-screenshot.png`: exact design-context screenshots. Visual reference only; never embed a screenshot as app UI.
- `b1-design-context.txt`, `b2-design-context.txt`: complete high-fidelity context text including asset URLs and tool instructions.
- `b1-structural-reference.tsx`, `b2-structural-reference.tsx`: generated structural references. Translate to native SwiftUI layout, state and controls; do not install React or Tailwind.
- `page-metadata.xml`: discovered hierarchy and geometry.
- `motion-context.json`: recursive motion reads for these two frames; both returned `nodes: []`. This does not establish that other prototype nodes have no animation. The written Social Objects motion score remains the implementation brief.
- `asset-manifest.json`: exact source URLs and download validation. Assets must be validated as SVG, not merely nonempty files. This runtime's requests returned HTML; missing assets must not be silently substituted.

## Composition

Both screens use Carbon `#080A0B`, Porcelain `#F5F6F2`, 24-point padding (25 including the frame border), 16-point vertical gaps, a brand/progress row, a large two-line headline and a bottom 345 × 56 primary action. The rounded 393 × 852 outer frame is a presentation boundary, not a requirement to draw a phone-shaped border inside the iOS safe area.

B1 headline: `WHICH BAND / TONIGHT?`; supporting text: `One intent. Your kind of connection.` Four 345 × 77 band groups contain 335 × 65 colored strips and 58 × 69 metal clasps. Intents/subtitles: Social / Friends & crews; Dating / Open to a match; Business / Ideas & networks; Activity / Do something together. Cyan, pink, yellow and green are exact intent tokens. The four custom SVG clasp icons occupy 31 × 31 slots. CTA `Choose Social` is the sample state; implementation must derive it from the actual choice.

B2 headline: `MAKE YOUR / HELLO CLEAR.` The sample intent subtitle is `Social`. A 345 × 100 band/tag stage precedes a 2 × 2 tag grid: 166 × 100 cards, 13-point horizontal and 12-point vertical spacing. The selected band strip is 317 × 50; the hero tag is 108 × 103. Four labels: Come say hi; Chat first; With my crew; Just looking. Choice icons are 32 × 32; the hero icon is 45 × 45. The current-state label is `Chosen signal: Chat first` and the CTA is `Set my signal`; both must reflect real local state where applicable.

Figma uses Barlow Semi Condensed ExtraBold (48-point headline, 31-point band words, 21-point tag words) and Inter for interface text. Social Objects explicitly proposes evaluating condensed SF Pro and native body typography for the app, so native substitution is already within the brief; record the substitution and compare renders. Do not reproduce the study's 11-point supporting text by shrinking essential copy. Use Dynamic Type, a scrolling body and bottom safe-area action. Large text may require one tag column and taller controls.

## Product and fidelity boundaries

- B1 footer `Select any band · locks only when you join a session` is proposed prototype copy. Do not ratify final intent-lock semantics from it; Task 01 only edits a pre-check-in local draft.
- B2 footer `Visible only after venue check-in` is explanatory. Confirmation must end at `Ready for check-in` and `Demo — not visible to anyone`, never a live presence state.
- The Figma bands and metal tags are simple editable vector studies. The Social Objects PDF remains the aspirational photoreal material reference. Neither establishes production asset quality, motion playback, native accessibility or device performance.
- Custom icons are actual exported SVG assets, not SF Symbol codepoints. Obtain and validate the exact downloads before declaring fidelity complete. Keep their root dimensions and intended slots; do not derive paths from screenshots.
- No Code Connect mappings or named production components were returned for these frames. Suggested reusable native components are the shared screen scaffold/action, intent-band view, metal clasp, signal-tag choice and persistent selected-band/tag stage.

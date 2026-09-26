#!/usr/bin/env python3
"""Proximeet Places review: the downloads of one scope's build.

    python3 scripts/places_review_package.py ROOT OUT ARTIFACTS SCOPE

ROOT is the checkout, OUT build/artifacts/places, ARTIFACTS build/artifacts. The places scope makes
Places-Review.zip (an offline index.html with the approved references beside this build's captures,
the source and scope of every result, the manifest rows, the per-execution results, the logs, the
verdict and the recorded deviations), Places-Screens.zip (every screen, each file name saying whether it
is a real journey or a direct-launch fixture), Places-walkthrough-compact.zip (and the loose .mp4 when
re-encoded) and Places-walkthrough-original.zip. The signal and regressions scopes make
Places-Signal-Review.zip or Places-Regressions-Review.zip. Every archive gets a .sha256 beside it.
Every relative link in an index must name a file in its archive; a broken link fails the stage.
Standard library only; Python 3.8+.
"""
import hashlib
import html
import json
import os
import re
import shutil
import sys
import zipfile

INTENTS = ("social", "dating", "business", "activity")
VENUES = (("common-ground", "Common Ground", "now"), ("afterglow", "Afterglow", "later"),
          ("fieldwork", "Fieldwork", "upcoming"))
SCREENS = (("01-now", "Now: Common Ground"), ("02-later", "Later: Afterglow"), ("03-upcoming", "Upcoming: Fieldwork"),
           ("04-common-ground", "Common Ground detail"), ("05-afterglow", "Afterglow detail"),
           ("06-fieldwork", "Fieldwork detail"), ("07-check-in-explanation", "Check-in explanation"))
JOURNEY = (
    ("places-journey-signal-social-chat", "Signal: Social, Chat first, before Continue preview"),
    ("places-journey-now-social", "Continue preview: Places opens at Now"),
    ("places-journey-later-social", "Later"),
    ("places-journey-upcoming-social", "Upcoming (Social does not match Fieldwork)"),
    ("places-journey-detail-common-ground-social", "View place: Common Ground, Preview check-in enabled"),
    ("places-journey-explanation-social", "Preview check-in: the explanation"),
    ("places-journey-back-to-place-social", "Back to place: Common Ground's detail"),
    ("places-journey-explore-now-social", "Explore other places: Now"),
    ("places-journey-detail-afterglow-social", "Afterglow: Opens at 9 pm (disabled; a tap does nothing)"),
    ("places-journey-detail-fieldwork-social", "Fieldwork: Not available for Social"),
    ("places-journey-back-to-signal", "Back to Signal: both values kept"),
    ("places-journey-reentry-upcoming-social", "Continue preview again: Upcoming kept"),
    ("places-journey-upcoming-business", "After changing the band to Business: Upcoming recomputed"),
    ("places-journey-detail-fieldwork-business", "Fieldwork for Business: Opens Saturday"),
    ("places-journey-detail-common-ground-business", "Common Ground for Business: Preview check-in enabled"),
    ("places-journey-explanation-business", "The explanation, Business"),
)
OTHERS = (
    ("places-back-to-places-later-fixture", "Back to places: Later kept"),
    ("places-reentry-after-card-later-fixture", "Back to the Guest List card and forward again: Later kept"),
    ("places-band-before-social-upcoming-fixture", "Band change: before (Social, Upcoming)"),
    ("places-band-business-upcoming-fixture", "Band change: Business, Upcoming"),
    ("places-band-business-common-ground-fixture", "Band change: Business, Common Ground"),
    ("places-band-activity-upcoming-fixture", "Band change: Activity, Upcoming"),
    ("places-band-activity-common-ground-fixture", "Band change: Activity, Common Ground"),
    ("places-guarded-explanation-dating-fixture", "Guarded destination: Dating stays on the detail"),
    ("places-guarded-explanation-activity-fixture", "Guarded destination: Activity stays on the detail"),
    ("places-age-gate-under18-fixture", "Back to Birthday, under 18: Places unreachable"),
    ("places-age-gate-forward-again-fixture", "Corrected, the Pass again, forward: Later kept"),
    ("places-after-relaunch-now-dating", "After relaunch (real route, Dating): Now, nothing kept"),
    ("places-after-rapid-tabs-fixture", "Four tabs in quick succession: the last"),
    ("places-view-place-after-tab-fixture", "View place straight after a tab"),
    ("places-back-after-view-place-fixture", "Back straight after View place"),
    ("places-after-background-resume-fixture", "Background straight after View place, then resume"),
    ("places-reduce-motion-preview-detail-fixture", "Reduce Motion preview flag: the detail, dissolved in"),
)
DEVIATIONS = (
    ("Signal to Places and back", "Figma dissolves (240 ms) between Signal and Places browsing. The app pushes and pops "
     "Places on the navigation stack, as every earlier chapter moves between chapters. Inside Places the approved "
     "motion is kept: category dissolves, the 500 ms ticket expansion, dissolves for the detail's Back and the "
     "explanation."),
    ("One destination, three stages", "Browsing, a detail and the explanation are one navigation destination whose "
     "stage comes from the domain, so they can dissolve and expand as approved. A system edge swipe, where available, "
     "therefore leaves Places for Signal from any stage; the on-screen Backs go one stage up."),
    ("The expansion", "The ticket keeps its identity between browsing and its detail, so SwiftUI moves the scene, the "
     "name and the kind to their detail places and cross-fades the lower parts (the chips and the footer out; the "
     "perforation, schedule, chips, host, description, rules and last line in). Figma's smart animate interpolates "
     "matching layers instead; the chips are faded, not flown."),
    ("Reduce Motion and VoiceOver", "Reduce Motion (the system setting or the app's preview flag) replaces the "
     "expansion with the 240 ms dissolve; VoiceOver gets no animation. Only the preview flag was tested."),
    ("The disabled reason", "Visible without a tap: the disabled action's own label (Opens at 9 pm, Opens Saturday, "
     "Not available for [Intent]) and, for a mismatch, the ticket's last line. Its accessibility hint adds the full "
     "sentence (for example: This fictional session is not open in the demo snapshot. Opens at 9 pm.)."),
    ("Larger text and smaller phones", "The tabs, the chips and the browse footer stack instead of truncating; every "
     "part scrolls. On a narrower phone the column is the width minus 64 pt and the scene slot scales with it (the "
     "art is fitted, never stretched)."),
    ("The browse ticket", "One accessible action (a button with the venue, kind, intents and schedule); View place is "
     "part of it, not a separate button."),
)


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as data:
        for block in iter(lambda: data.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def read(path):
    return open(path, encoding="utf-8", errors="replace").read() if os.path.isfile(path) else ""


def kv(path):
    values = {}
    for line in read(path).splitlines():
        key, sep, value = line.partition("=")
        if sep:
            values.setdefault(key, value)
    return values


def walk(node, test=None):
    # xcresulttool's manifest: [{testIdentifier, attachments: [{exportedFileName, suggestedHumanReadableName, timestamp}]}]
    if isinstance(node, dict):
        test = node.get("testIdentifier", test)
        exported, readable = node.get("exportedFileName"), node.get("suggestedHumanReadableName")
        if exported and readable:
            yield str(exported), str(readable), float(node.get("timestamp") or 0), test or "?"
        for value in node.values():
            yield from walk(value, test)
    elif isinstance(node, list):
        for value in node:
            yield from walk(value, test)


def main(argv):
    if len(argv) != 5:
        sys.stderr.write(__doc__)
        return 2
    root, out, artifacts, scope = argv[1:5]
    places = scope == "places"
    title = {"places": "Places-Review", "signal": "Places-Signal-Review"}.get(scope, "Places-Regressions-Review")
    out_zip = os.path.join(artifacts, title + ".zip")
    ref = os.path.join(root, "docs/design/places-approved/reference")
    entries, missing = [], []

    def add(name, source, required=True):
        if os.path.isfile(source):
            entries.append((name, source))
            return name
        if required:
            missing.append(name)
        return None

    board = add("approved/places-review.png", os.path.join(ref, "places-review.png"), required=places)
    deliveries = {key: add("approved/%s-delivery.png" % key, os.path.join(ref, "%s-delivery.png" % key), required=places)
                  for key, _, _ in VENUES}
    compact = add("captures/places-walkthrough-compact.mp4", os.path.join(out, "places-walkthrough-compact.mp4"),
                  required=places)
    original = add("captures/places-walkthrough-original.mp4", os.path.join(out, "places-walkthrough-original.mp4"),
                   required=places)
    for key in sorted(os.listdir(out)) if os.path.isdir(out) else []:
        if key.endswith(("-summary.json", "-tests.json", ".sha256")) or key in (
                "verdict.txt", "ui-review-tests.txt", "ui-review-counts.txt", "runs.txt", "destination.txt",
                "source-checkpoint.txt", "compact-video.txt", "smaller.txt", "executions.tsv", "manifest-rows.tsv"):
            add("results/" + key, os.path.join(out, key), required=key == "verdict.txt")
    add("results/summary.txt", os.path.join(artifacts, "summary.txt"))
    add("results/places-review-manifest.tsv", os.path.join(root, "docs/verification/places-review-manifest.tsv"))
    for folder, prefix in (("metadata", "results/metadata/"), ("logs", "logs/")):
        directory = os.path.join(artifacts, folder)
        for name in sorted(os.listdir(directory)) if os.path.isdir(directory) else []:
            if name.endswith((".txt", ".log", ".json", ".env")) and os.path.isfile(os.path.join(directory, name)):
                add(prefix + name, os.path.join(directory, name))
    app_dir = os.path.join(artifacts, "app")
    apps = sorted(n for n in os.listdir(app_dir) if n.endswith((".zip", ".sha256"))) if os.path.isdir(app_dir) else []
    for name in apps:
        add("app/" + name, os.path.join(app_dir, name))
    if not any(n.endswith(".zip") for n in apps):
        missing.append("app/Proximeet-Debug-iphonesimulator-*.zip")

    # Every screenshot and note from every run. Retries are off, so a name appears once per test;
    # a name attached twice keeps its latest image.
    shots, stamps, notes, used = {}, {}, [], set()
    folders = sorted(n for n in os.listdir(out) if n.startswith("attachments-")) if os.path.isdir(out) else []
    for folder in folders:
        directory = os.path.join(out, folder)
        try:
            items = list(walk(json.load(open(os.path.join(directory, "manifest.json")))))
        except (OSError, ValueError):
            items = [(n, n, 0.0, "?") for n in sorted(os.listdir(directory))] if os.path.isdir(directory) else []
        for exported, readable, stamp, test in items:
            source = os.path.join(directory, exported)
            extension = os.path.splitext(exported)[1].lower()
            if extension not in (".png", ".jpg", ".jpeg", ".txt", ".json") or not os.path.isfile(source):
                continue
            base = readable.split("_0_")[0]
            safe = "".join(c if c.isalnum() or c in "-_." else "_" for c in base)
            if not safe.lower().endswith(extension):
                safe += extension
            stem, candidate, n = safe[:-len(extension)], safe, 1
            while candidate in used:
                n += 1
                candidate = "%s-%d%s" % (stem, n, extension)
            used.add(candidate)
            name = add("xctest/" + candidate, source)
            if extension in (".png", ".jpg", ".jpeg"):
                if base not in shots or stamp >= stamps[base]:
                    shots[base], stamps[base] = name, stamp
            elif extension == ".txt":
                notes.append("%s (%s): %s" % (test.split("/")[-1].replace("()", ""), folder.replace("attachments-", ""),
                                              read(source).strip()))

    verdict = read(os.path.join(out, "verdict.txt")) or "No verdict was produced in this run."
    headline = next((l for l in verdict.splitlines() if l.startswith("AUTOMATED VERDICT")), "AUTOMATED VERDICT: not produced")
    checkpoint = kv(os.path.join(out, "source-checkpoint.txt"))
    head = checkpoint.get("git_head", "unknown")
    compact_info = kv(os.path.join(out, "compact-video.txt"))
    compact_note = compact_info.get("result", "not produced")
    smaller_device = kv(os.path.join(out, "smaller.txt")).get("device", "not run")
    build_id = os.environ.get("CM_BUILD_ID", "")
    build_label = ("Codemagic build %s" % build_id) if build_id else "a simulator run outside Codemagic"
    record = os.environ.get("PLACES_SCOPE_RECORD", "").strip()
    results = {}
    for line in read(os.path.join(out, "ui-review-tests.txt")).splitlines():
        if re.match(r"^\w+Tests\.test\w+\[", line):
            key, _, value = line.partition("=")
            name, _, device = key.partition("[")
            results.setdefault(name, []).append("%s: %s" % (device.rstrip("]"), value))

    def img(name, caption):
        if not name:
            return '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption)
        return '<figure><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>' % (
            name, html.escape(caption), html.escape(caption))

    def approved(index, caption):
        # The board is 1480 x 1670 at 1x; its three frames (440 x 956) sit at x 40 / 520 / 1000, y 172.
        # Shown at 0.75.
        if not board:
            return '<p class="missing">Approved reference missing.</p>'
        return ('<figure><div class="crop" style="background-image:url(%s);background-position:-%dpx -129px"></div>'
                '<figcaption>%s</figcaption></figure>') % (board, [30, 390, 750][index], html.escape(caption))

    def cards():
        # The board's Later and Upcoming summaries (y 1260-1550 at 1x), shown at 0.75.
        if not board:
            return ""
        return ('<figure><div class="cards" style="background-image:url(%s)"></div><figcaption>Approved board: Afterglow '
                '(Later) and Fieldwork (Upcoming)</figcaption></figure>') % board

    def delivery(key, caption):
        name = deliveries.get(key)
        if not name:
            return '<p class="missing">%s: approved delivery missing.</p>' % html.escape(caption)
        return '<figure><img class="delivery" src="%s" alt="%s"><figcaption>%s</figcaption></figure>' % (
            name, html.escape(caption), html.escape(caption))

    def shot(key, caption):
        return img(shots.get(key), caption)

    def video(name, caption):
        if not name:
            return '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption)
        return ('<figure><video src="%s" controls muted playsinline preload="metadata"></video><figcaption>%s</figcaption>'
                '</figure>') % (name, html.escape(caption))

    def row(*cells):
        return '<div class="row">%s</div>' % "".join(cells)

    def widths(prefix):
        # Capture names end in -<width>pt-fixture; the widths found, widest first.
        found = {m.group(1) for k in shots for m in [re.match(re.escape(prefix) + r".*-(\d+)pt-fixture$", k)] if m}
        return sorted(found, key=int, reverse=True)

    test_rows = "".join("<tr><td>%s</td><td>%s</td></tr>" % (html.escape(t), html.escape("; ".join(r)))
                        for t, r in sorted(results.items()))
    manifest_rows = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % html.escape(c) for c in line.split("\t"))
                            for line in read(os.path.join(out, "manifest-rows.tsv")).splitlines() if line.strip())
    scope_rows = ("<tr><td>%s</td><td>%s</td><td><code>%s</code></td><td>%s</td></tr>"
                  % (html.escape(scope), html.escape(build_label), html.escape(head), html.escape(headline)))
    if record:
        for item in record.split(";"):
            parts = [p.strip() for p in item.split(":")]
            if len(parts) == 3 and parts[0] != scope:
                scope_rows += ("<tr><td>%s</td><td>Codemagic build %s (reported at dispatch; not read by this build)"
                               "</td><td><code>%s</code></td><td>see that build's own verdict</td></tr>"
                               % tuple(html.escape(p) for p in parts))
    others = [s for s in ("places", "signal", "regressions") if s != scope]
    scope_note = ("The other scopes (%s) run as their own builds, each on a pinned commit named in its own verdict; "
                  "the final report lists every build, scope and commit." % ", ".join(others))

    if places:
        sections = [
            ("Walkthrough: the real journey from Welcome, through Birthday, the Pass, the Guest List, the Wristband "
             "and Signal, into Places",
             row(video(compact, "Compact walkthrough: %s%s" % (compact_note, (", trimmed " + compact_info["trim"])
                                                              if compact_info.get("trim") else "")),
                 video(original, "Original simulator recording, unedited"))),
            ("The approved design (Social) beside the real journey",
             row(shot("places-journey-now-social", "This run (XCTest, real route): Now"),
                 shot("places-journey-detail-common-ground-social", "This run: Common Ground's detail"),
                 shot("places-journey-explanation-social", "This run: the check-in explanation")) +
             row(approved(0, "Approved: Now (58:480)"), approved(1, "Approved: Common Ground's detail (58:483)"),
                 approved(2, "Approved: the explanation (58:486)"))),
            ("Later and Upcoming beside the approved board and scenes",
             row(shot("places-journey-detail-afterglow-social", "This run: Afterglow, Social"),
                 shot("places-journey-detail-fieldwork-social", "This run: Fieldwork, Social")) +
             row(cards()) +
             row(*[delivery(key, "Approved scene delivery: %s" % name) for key, name, _ in VENUES])),
            ("The seven screens (XCTest, direct launches, Social; frames and drawing checked on the 440-pt iPhone)",
             "".join(row(*[shot("places-screen-%s-social-%spt-fixture" % (key, width), "%s, %s pt (FIXTURE)" % (label, width))
                           for key, label in SCREENS]) for width in widths("places-screen-"))
             or '<p class="missing">The seven screens: not produced in this run.</p>'),
            ("Eligibility: every intent at every venue (XCTest, direct launches)",
             "".join(row(*[shot("places-eligibility-%s-%s-fixture" % (key, intent), "%s at %s" % (intent.title(), name))
                           for key, name, _ in VENUES]) for intent in INTENTS)),
            ("The journey, step by step (XCTest, real route)",
             row(*[shot(key, caption) for key, caption in JOURNEY])),
            ("Routes, the band, the Birthday gate, relaunch, interruptions and Reduce Motion",
             row(*[shot(key, caption) for key, caption in OTHERS])),
            ("Largest accessibility text size (direct launches; each width in turn)",
             row(*[img(v, k.replace("places-largest-text-", "").replace("-fixture", "")) for k, v in sorted(
                 ((k, v) for k, v in shots.items() if k.startswith("places-largest-text-")),
                 key=lambda item: (-int(re.search(r"-(\d+)pt-", item[0]).group(1)) if re.search(r"-(\d+)pt-", item[0]) else 0,
                                   item[0]))])
             or '<p class="missing">Largest-text captures: not produced in this run.</p>'),
        ]
    elif scope == "signal":
        sections = [
            ("Signal's Continue preview now opens Places",
             row(shot("signal-journey-continue-places", "Real journey: Continue preview opens Places at Now"),
                 shot("signal-continue-places-fixture", "Double tap on Continue preview: Places opens"),
                 shot("06-places", "Interaction test: Places"), shot("08-reduced-motion-places", "Reduce Motion: Places"))),
            ("Every capture of this build", row(*[img(v, k) for k, v in sorted(shots.items())])),
        ]
    else:
        sections = [("Every capture of this build", row(*[img(v, k) for k, v in sorted(shots.items())]))]
    if places and not widths("places-screen-"):
        missing.append("the seven screens (places-screen-*)")
    body = "".join("<h2>%s</h2>%s" % (html.escape(t), content) for t, content in sections)
    deviation_rows = "".join("<tr><td>%s</td><td>%s</td></tr>" % (html.escape(a), html.escape(b)) for a, b in DEVIATIONS)
    try:
        simulator = json.load(open(os.path.join(artifacts, "metadata", "simulator.json")))
    except (OSError, ValueError):
        simulator = {}
    page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Proximeet Places review (%s)</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;margin:24px;background:#111;color:#eee}
h1{font-size:22px}h2{font-size:17px;margin-top:32px;border-top:1px solid #333;padding-top:16px}
.row{display:flex;flex-wrap:wrap;gap:20px;margin-bottom:16px}figure{margin:0}
figcaption{color:#aaa;font-size:13px;max-width:330px}
img,video{width:330px;max-width:100%%;border:1px solid #333;border-radius:8px;background:#000}
img.delivery{width:216px;height:auto;background:#050606}
.crop{width:330px;height:717px;border:1px solid #333;border-radius:8px;background-repeat:no-repeat;background-size:1110px 1252.5px}
.cards{width:1050px;max-width:100%%;height:230px;border:1px solid #333;border-radius:8px;background-repeat:no-repeat;background-size:1110px 1252.5px;background-position:-30px -935px}
table{border-collapse:collapse;max-width:1100px}td,th{border:1px solid #333;padding:6px 8px;vertical-align:top;font-size:13px;text-align:left}
pre{white-space:pre-wrap;background:#1b1b1b;padding:12px;border-radius:8px;font-size:12px}.missing{color:#f99}
.note{color:#ccc;max-width:780px}</style></head><body>
<h1>Proximeet Places: iOS Simulator review, scope “%s”</h1>
<p><b>%s</b></p>
<table><tr><th>Scope</th><th>Build</th><th>Source commit</th><th>Result</th></tr>%s</table>
<p class="note">%s Real captures from %s (%s, %s; the smaller iPhone, %s, where a caption names another width).
The approved design they are compared with is unchanged. Captures named “journey” come from the real route, driven by
real taps and typing. Captures marked FIXTURE open a prepared state directly (a direct launch through the same gates).
Every venue, host and schedule is fictional; the snapshot is a fixed Thursday, 8 pm. Places keeps everything in memory
for the run. Browsing, a detail and the explanation request no permission, use no location or camera, check nobody in,
reserve nothing and make nobody visible. Automated checks are not visual approval; that is the founder's decision.
The simulator app cannot be installed on an iPhone.</p>
%s
<h2>Deviations from the approved design, recorded</h2><table><tr><th>What</th><th>How the app does it</th></tr>%s</table>
<h2>This scope's manifest</h2><table><tr><th>Scope</th><th>Order</th><th>Device</th><th>Run</th><th>Bundle</th><th>Bound (s)</th><th>Test</th><th>Kind</th></tr>%s</table>
<h2>Every test in this build</h2><table><tr><th>Test</th><th>Device: outcome (duration)</th></tr>%s</table>
<p class="note">The Reduce Motion screens use the app's preview flag, not the system setting. VoiceOver, composing
keyboards, the system Reduce Motion setting, other orientations and on-device motion are manual checks.</p>
<h2>Notes attached by the tests</h2><pre>%s</pre>
<h2>Result</h2><pre>%s</pre>
<p>Unsigned simulator app (simulator only): %s</p>
<p>Details: %s</p>
<p class="missing">%s</p>
</body></html>""" % (
        html.escape(scope), html.escape(scope), html.escape(headline), scope_rows, html.escape(scope_note),
        html.escape(build_label), html.escape(simulator.get("device_name", "an unrecorded simulator")),
        html.escape(simulator.get("runtime_name", "an unrecorded runtime")), html.escape(smaller_device), body,
        deviation_rows, manifest_rows, test_rows, html.escape("\n\n".join(notes) or "none"), html.escape(verdict),
        " ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries if n.startswith("app/") and n.endswith(".zip"))
        or "not produced",
        " | ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries
                   if n.startswith(("results/", "logs/")) or (n.startswith("xctest/") and n.endswith((".txt", ".json")))),
        ("Not produced in this run: " + ", ".join(missing)) if missing else "")

    # Every relative link and image in the page must name a file in the archive.
    targets = set(re.findall(r'(?:src|href)="([^"#:]+)"', page)) | set(re.findall(r"url\(([^)]+)\)", page))
    packed = {n for n, _ in entries}
    broken = sorted(t for t in targets if t not in packed)
    if broken:
        print("BROKEN relative links in index.html: " + ", ".join(broken))
    os.makedirs(artifacts, exist_ok=True)
    with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED) as bundle:
        bundle.writestr(title + "/index.html", page)
        for name, source in entries:
            bundle.write(source, title + "/" + name)
    print("%s.zip: %d files, %d relative links checked, %d broken%s" % (
        title, len(entries) + 1, len(targets), len(broken), ("; missing: " + ", ".join(missing)) if missing else ""))
    open(os.path.join(out, "package-links.txt"), "w").write("links=%d\nbroken=%s\nmissing=%s\n" % (
        len(targets), ",".join(broken) or "none", ",".join(missing) or "none"))
    made = [title + ".zip"]

    if places:
        sources = dict(entries)
        readme = ("%s\nProximeet Places, source %s, %s, on %s, %s. File names say where each screen came from: XCTest-journey "
                  "is the real route (real taps from Welcome); XCTest-FIXTURE-direct-launch opens a prepared state "
                  "directly, through the same gates. Every venue, host and schedule is fictional; nothing is checked in, "
                  "reserved or made visible, and no permission is requested. The approved references, the deviations and "
                  "the full verdict (results/verdict.txt) are in Places-Review.zip. Automated checks are not visual "
                  "approval.\n" % (headline, head, build_label, simulator.get("device_name", "an unrecorded simulator"),
                                   simulator.get("runtime_name", "an unrecorded runtime")))
        screens = []
        for width in widths("places-screen-"):
            for key, label in SCREENS:
                screens.append(("places-screen-%s-social-%spt-fixture" % (key, width),
                                "Places-%s-%s-social-%spt-XCTest-FIXTURE-direct-launch.png" % (width, key, width)))
        for key, _, _ in VENUES:
            for intent in INTENTS:
                screens.append(("places-eligibility-%s-%s-fixture" % (key, intent),
                                "Eligibility-%s-%s-XCTest-FIXTURE-direct-launch.png" % (key, intent)))
        for number, (key, _) in enumerate(JOURNEY, start=1):
            screens.append((key, "Journey-%02d-%s-XCTest-journey.png" % (number, key[len("places-journey-"):])))
        for key, _ in OTHERS:
            label = "XCTest-journey" if not key.endswith("-fixture") else "XCTest-FIXTURE-direct-launch"
            screens.append((key, "Other-%s-%s.png" % (key[len("places-"):].replace("-fixture", ""), label)))
        for key in sorted(k for k in shots if k.startswith("places-largest-text-")):
            screens.append((key, "Largest-text-%s-XCTest-FIXTURE-direct-launch.png"
                            % key[len("places-largest-text-"):].replace("-fixture", "")))
        with zipfile.ZipFile(os.path.join(artifacts, "Places-Screens.zip"), "w", zipfile.ZIP_STORED) as bundle:
            bundle.writestr("README.txt", readme)
            for key, target in screens:
                name = shots.get(key)
                if name and name in sources:
                    bundle.write(sources[name], target)
                else:
                    bundle.writestr(target + ".MISSING.txt", "Not produced in this run.\n")
            if notes:
                bundle.writestr("Notes-attached-by-the-tests.txt", "\n\n".join(notes) + "\n")
        made.append("Places-Screens.zip")
        if compact:
            reencoded = compact_note == "RE-ENCODED"
            if reencoded:
                inner = "Places-walkthrough-compact-RE-ENCODED-TRIMMED.mp4"
                label = ("Compact walkthrough: RE-ENCODED and TRIMMED to the app (%s; %s). A half-size AVFoundation "
                         "re-encode, not the original encoding. The unedited recording is in "
                         "Places-walkthrough-original.zip.\n" % (compact_info.get("method", "AVFoundation export"),
                                                                 compact_info.get("trim", "trim not recorded")))
            else:
                inner = "Places-walkthrough-FALLBACK-COPY-not-re-encoded-not-trimmed.mp4"
                label = ("Compact walkthrough: %s. The re-encode did not complete, so this is a plain copy of the "
                         "unedited recording: not re-encoded and not trimmed.\n" % compact_note)
            with zipfile.ZipFile(os.path.join(artifacts, "Places-walkthrough-compact.zip"), "w", zipfile.ZIP_STORED) as bundle:
                bundle.writestr("README.txt", readme + label)
                bundle.write(sources[compact], inner)
            made.append("Places-walkthrough-compact.zip")
            if reencoded:
                shutil.copyfile(sources[compact], os.path.join(artifacts, "Places-walkthrough-compact.mp4"))
                made.append("Places-walkthrough-compact.mp4")
        if original:
            with zipfile.ZipFile(os.path.join(artifacts, "Places-walkthrough-original.zip"), "w", zipfile.ZIP_STORED) as bundle:
                bundle.writestr("README.txt", readme + "The unedited simulator recording of the real journey.\n")
                bundle.write(sources[original], "Places-walkthrough-original.mp4")
            made.append("Places-walkthrough-original.zip")
    for name in made:
        path = os.path.join(artifacts, name)
        open(path + ".sha256", "w").write("%s  %s\n" % (sha256(path), name))
        print("%s sha256 %s" % (name, sha256(path)))
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

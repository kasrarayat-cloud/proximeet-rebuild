#!/usr/bin/env python3
"""Proximeet Places review: the downloads of one scope's build.

    python3 scripts/places_review_package.py ROOT OUT ARTIFACTS SCOPE

ROOT is the checkout, OUT build/artifacts/places, ARTIFACTS build/artifacts. The places scope makes
Places-Review.zip (an offline index.html with the approved references beside this build's captures,
the source and scope of every result, the manifest rows, the per-execution results, the logs, the
verdict and the recorded deviations), Places-Screens.zip (every screen, each file name saying whether it
is a real journey or a direct-launch fixture), Places-walkthrough-compact.zip (and the loose .mp4 when
re-encoded) and Places-walkthrough-original.zip. The sweep scope (the places scope's P rows and the
signal scope's S rows that the correction does not run) makes the same under the prefix Places-Sweep
(Places-Sweep-Review.zip, Places-Sweep-Screens.zip; no recording: its P1 runs with short holds), naming
the captures of P7 and P8 as the correction build's, with
its S rows' captures beside the Places ones and every P and S execution listed by row, device and
outcome. The signal and regressions scopes make Places-Signal-Review.zip or
Places-Regressions-Review.zip. The correction scope makes Places-Correction-Review.zip (before and
after, the source and its changed files, every execution by test and device, the earlier coverage it
executes and where the rest is due, logs, the verdict, a checksum of every file inside),
Places-Correction-Screens.zip and Places-Correction-walkthrough.zip (the recording, unedited). The
gate_finish scope (recovery build 3) makes Places-Gate-Review.zip, a page like the correction's that
shows this build's correction captures (C1-C9 on the iPhone 17 Pro Max) and names C10-C15, and the
captures they made on the smaller iPhone, as recovery build 2's; its extras' captures follow; and
Places-Gate-Screens.zip. The sweep_finish scope (recovery build 4) makes Places-Finish-Review.zip, a
page like the sweep's with the P, S, M and B rows it runs, naming every capture that another recovery
build makes, and Places-Finish-Screens.zip. Neither records anything. The regression_finish scope
(recovery build 5) makes Places-Remaining-Review.zip, a page like the regressions scope's with its 16
rows, each on the lane it actually ran on (its screens are inside; its result bundles are zipped
separately by scripts/places_review.sh as Places-Remaining-Results.zip). An unknown scope (the retired
sweep_places and sweep_signal included) makes nothing (exit 2), so no archive can carry another
scope's name. Every archive gets a .sha256 beside it.
Every relative link in an index must name a file in its archive; a broken link fails the stage.
Standard library only; Python 3.8+.
"""
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
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
# Every scope's review archive, and the prefix of its screens and walkthrough archives (places-like
# scopes only). Nothing falls back to another scope's name.
PACKAGES = {
    "places": ("Places-Review", "Places"),
    "sweep": ("Places-Sweep-Review", "Places-Sweep"),
    "signal": ("Places-Signal-Review", None),
    "regressions": ("Places-Regressions-Review", None),
    "correction": ("Places-Correction-Review", "Places-Correction"),
    "gate_finish": ("Places-Gate-Review", "Places-Gate"),
    "sweep_finish": ("Places-Finish-Review", "Places-Finish"),
    "regression_finish": ("Places-Remaining-Review", None),
}
# The recovery after the Places correction, and the role and number each build's pages name. Build 1
# (the first correction build, 6ab8adb4 on 907d7401) counts toward none of it. Build 2 (6ab8c585, scope
# correction, on 808950f) passed C10-C15 on the smaller iPhone; on the iPhone 17 Pro Max its test runner
# failed to initialize for UI testing before any test started. Builds 3 and 4 finish it.
RECOVERY = ("correction", "gate_finish", "sweep_finish")
RECOVERY_ROLE = {"correction": "correction gate, build 2", "gate_finish": "gate finish, build 3",
                 "sweep_finish": "sweep finish, build 4"}
# The commit of the first correction build (Codemagic 6ab8adb4): 14 of its 15 required rows passed and
# C12 failed on a product issue; the correction page shows what changed in the product since.
FIRST_CORRECTION_COMMIT = "907d7401ec8b97a10138c2764094a9c564d0e4ce"
# Build 2's commit and ID; builds 3 and 4 count only where their product and test files equal it.
REFERENCE = "808950f8102d1c0e0f6c3422fc0aed3a0df555fe"
BUILD2_ID = "6ab8c585873de42fcd4f1a8a"
PRODUCT_PATHS = ("Proximeet", "ProximeetDomain", "ProximeetUITests", "Proximeet.xcodeproj", "assets")
CORRECTION_SCREENS, GATE_SCREENS = "Places-Correction-Screens.zip", "Places-Gate-Screens.zip"
BUILD2_NOTE = ("recovery build 2 (Codemagic %s, scope correction, on %s), where C10-C15 passed on the smaller iPhone"
               % (BUILD2_ID, REFERENCE[:12]))
CLASS = {"main": "main", "b": "main", "small": "small"}
# Captures the sweep build does not make, because P7 and P8 run in the correction build:
# (capture name prefix, suffix, where it is made, the archive that holds it).
SWEEP_ELSEWHERE = (
    ("places-screen-", "-440pt-fixture", "P7 (the seven screens on the iPhone 17 Pro Max) runs in the correction build as C9",
     CORRECTION_SCREENS),
    ("places-back-to-places-later-fixture", "", "P8 (Back routes, smaller iPhone) runs in the correction build as C15",
     CORRECTION_SCREENS),
    ("places-reentry-after-card-later-fixture", "", "P8 (Back routes, smaller iPhone) runs in the correction build as C15",
     CORRECTION_SCREENS),
)
# Captures of the places scope's rows that sweep_finish (recovery build 4) does not make, and where they
# are made instead.
FINISH_ELSEWHERE = (
    ("places-screen-", "-440pt-fixture", "P7 (the seven screens on the iPhone 17 Pro Max) runs in recovery build 3 "
     "(gate_finish) as C9", GATE_SCREENS),
    ("places-screen-", "pt-fixture", "P13 (the seven screens on the smaller iPhone) runs in recovery build 3 "
     "(gate_finish) as an extra", GATE_SCREENS),
    ("places-eligibility-", "-fixture", "P10 (every intent at every venue, smaller iPhone) runs in recovery build 3 "
     "(gate_finish) as an extra", GATE_SCREENS),
    ("places-band-", "-fixture", "P9 (the band change, smaller iPhone) runs in recovery build 3 (gate_finish) as an "
     "extra", GATE_SCREENS),
    ("places-guarded-explanation-", "-fixture", "P12 (missing choices and the guarded explanation, smaller iPhone) runs "
     "in recovery build 3 (gate_finish) as an extra", GATE_SCREENS),
    ("places-back-to-places-later-fixture", "", "P8 (Back routes, smaller iPhone) ran in recovery build 2 (correction) "
     "as C15", CORRECTION_SCREENS),
    ("places-reentry-after-card-later-fixture", "", "P8 (Back routes, smaller iPhone) ran in recovery build 2 "
     "(correction) as C15", CORRECTION_SCREENS),
)
# The classes whose tests are the regression rows (M and B) in sweep_finish.
REGRESSION_CLASSES = ("BirthdayReviewTests", "WristbandReviewTests", "PassReviewTests", "GuestListReviewTests",
                      "WelcomeReviewTests")
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


def git_in(root, *args):
    result = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def product_changes(root):
    """The product and test files that differ between HEAD and build 2's commit: "none", a list, or why unknown."""
    if git_in(root, "rev-parse", "HEAD") is None:
        return "unavailable (git)"
    changed = git_in(root, "diff", "--name-status", REFERENCE, "HEAD", "--", *PRODUCT_PATHS)
    if changed is None:
        return "unavailable (git diff %s HEAD failed)" % REFERENCE[:12]
    return changed or "none"


def coverage_lines(root):
    """docs/verification/places-recovery-coverage.tsv, one dict per target."""
    columns = ("target", "requirement", "test", "class", "build", "scope", "run", "row", "kind", "note")
    lines = []
    for line in read(os.path.join(root, "docs/verification/places-recovery-coverage.tsv")).splitlines():
        cells = line.split("\t")
        if not line.startswith("#") and len(cells) == len(columns) and cells[0] != "target":
            lines.append(dict(zip(columns, cells)))
    return lines


def main(argv):
    if len(argv) != 5:
        sys.stderr.write(__doc__)
        return 2
    root, out, artifacts, scope = argv[1:5]
    if scope not in PACKAGES:
        print("unknown scope %r: no package is made (scopes: %s)" % (scope, ", ".join(sorted(PACKAGES))))
        return 2
    title, archive_prefix = PACKAGES[scope]
    places = scope in ("places", "sweep", "sweep_finish")
    sweep = scope == "sweep"
    finish = scope == "sweep_finish"
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

    board = add("approved/places-review.png", os.path.join(ref, "places-review.png"),
                required=places or scope in ("correction", "gate_finish"))
    deliveries = {key: add("approved/%s-delivery.png" % key, os.path.join(ref, "%s-delivery.png" % key), required=places)
                  for key, _, _ in VENUES}
    # Only the original places scope re-encodes its recording on the Mac; the sweep records nothing.
    compact = add("captures/places-walkthrough-compact.mp4", os.path.join(out, "places-walkthrough-compact.mp4"),
                  required=scope == "places")
    # The sweep records nothing: its P1 runs with short holds (docs/verification/places-review-manifest.tsv).
    original = add("captures/places-walkthrough-original.mp4", os.path.join(out, "places-walkthrough-original.mp4"),
                   required=scope in ("places", "correction"))
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
    shots, stamps, notes, used, shot_tests = {}, {}, [], set(), {}
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
                    shot_tests[base] = test
            elif extension == ".txt":
                notes.append("%s (%s): %s" % (test.split("/")[-1].replace("()", ""), folder.replace("attachments-", ""),
                                              read(source).strip()))

    if scope in ("correction", "gate_finish"):
        return package_correction(root, out, artifacts, title, archive_prefix, scope, entries, missing, shots,
                                  shot_tests, notes, board, original, add)

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

    def elsewhere(key):
        # In sweep (P7 and P8) and sweep_finish (P7-P13 but P11), where a capture this build does not make
        # is made: (what, archive), or None.
        table = SWEEP_ELSEWHERE if sweep else FINISH_ELSEWHERE if finish else ()
        return next(((where, archive) for start, end, where, archive in table
                     if key.startswith(start) and key.endswith(end)), None)

    def shot(key, caption):
        if key not in shots and elsewhere(key):
            return '<p class="note">%s: %s; see %s.</p>' % (html.escape(caption), html.escape(elsewhere(key)[0]),
                                                           html.escape(elsewhere(key)[1]))
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
    if finish:
        scope_note = ("This is the recovery build (%s) after the Places correction. Build 2 (Codemagic %s, scope correction, "
                      "on %s) passed C10-C15 on the smaller iPhone and C15 ran P8 there; on the iPhone 17 Pro Max its test "
                      "runner failed to initialize for UI testing before any test started. Build 3 (gate_finish) runs C1-C9, "
                      "which execute P7, S1, S2, S7, S11 and S14, and the extras S3-S6, S8, P9-P13, S15 and S16. This build "
                      "runs P1-P6 (P1, the real journey, with short holds and unrecorded), S9, S10, S12, S13 and M1-M3 on "
                      "the iPhone 17 Pro Max, and M4-M13, B1, B10-B13 and B15 on device B, its clone (the regressions scope "
                      "ran the M rows on main: the same model and runtime), each under its earlier row ID and listed below "
                      "by row, device and outcome. B2-B9 and the optional B14 run in no recovery build (pending). "
                      "scripts/places_recovery_reconcile.py reconciles the builds row by row, counting only builds whose "
                      "product and test files equal %s's. Product and test files changed since %s: %s."
                      % (RECOVERY_ROLE[scope], BUILD2_ID, REFERENCE[:12], REFERENCE[:12], REFERENCE[:12],
                         product_changes(root).replace("\n", "; ")))
    elif sweep:
        scope_note = ("The sweep was planned as the recovery's second build before recovery build 2 (Codemagic %s) left the "
                      "main device's rows unrun; the recovery now finishes with gate_finish and sweep_finish, reconciled "
                      "row by row by scripts/places_recovery_reconcile.py. This build runs the places scope's P rows and "
                      "the signal scope's S rows under their own IDs, listed below by row, device and outcome. P7 and P8 "
                      "run in the correction build, as C9 and C15, and S1, S2, S7, S11 and S14 as C4, C5, C6, C7 and C8 "
                      "(the same test on the same device, in the same short-hold run); their captures are in "
                      "Places-Correction-Screens.zip." % BUILD2_ID)
    elif scope == "regression_finish":
        scope_note = ("This is recovery build 5 (regression_finish), after build 4 (sweep_finish) ran out of time on a main "
                      "simulator that ran 2.7-7x slower per step. It runs the 16 earlier rows no recovery build had verified, "
                      "each under its earlier row ID: P3, P6 and M2 (interrupted in build 4, so these are disclosed repeated "
                      "executions), P1 (the real journey, short holds, unrecorded), S9, S10, S12 and S13 (never started in "
                      "build 4) and B2-B9 (the Guest List, never scheduled). Its runs are one queue shared by the two iPhone "
                      "17 Pro Max simulators (the selected one and device B, its clone: one device class); each result names "
                      "the lane it ran on (results/executions.tsv, results/runs.txt, results/metadata/places-queue-claims.txt). "
                      "Every run's result bundle is in Places-Remaining-Results.zip. The other 40 earlier rows passed in "
                      "builds 3 and 4; scripts/places_recovery_reconcile.py reconciles the builds row by row, counting only "
                      "builds whose product and test files equal %s's. Product and test files changed since %s: %s."
                      % (REFERENCE[:12], REFERENCE[:12], product_changes(root).replace("\n", "; ")))
    else:
        others = [s for s in ("places", "signal", "regressions") if s != scope]
        scope_note = ("The other scopes (%s) run as their own builds, each on a pinned commit named in its own verdict; "
                      "the final report lists every build, scope and commit." % ", ".join(others))

    if scope == "places":
        compact_cell = video(compact, "Compact walkthrough: %s%s" % (compact_note, (", trimmed " + compact_info["trim"])
                                                                    if compact_info.get("trim") else ""))
    else:
        compact_cell = ('<p class="note">Compact walkthrough: %s. No re-encode is made on the Mac for this scope; the '
                        'recording beside this note is the unedited original.</p>' % html.escape(compact_note))
    if sweep or finish:
        walkthrough = ("Walkthrough: not recorded in this build",
                       '<p class="note">No walkthrough is recorded in the %s: its P1 (the real journey) runs with '
                       'short holds in %s, unrecorded. The recovery\'s walkthrough is %s\'s C10, in '
                       'Places-Correction-walkthrough.zip.</p>'
                       % ("sweep" if sweep else "sweep_finish scope", "places_main" if sweep else "places_signal_main",
                          "the correction build" if sweep else "recovery build 2"))
    else:
        walkthrough = ("Walkthrough: the real journey from Welcome, through Birthday, the Pass, the Guest List, the "
                       "Wristband and Signal, into Places",
                       row(compact_cell, video(original, "Original simulator recording, unedited")))
    if places:
        sections = [
            walkthrough,
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
             ("".join(row(*[shot("places-screen-%s-social-%spt-fixture" % (key, width), "%s, %s pt (FIXTURE)" % (label, width))
                            for key, label in SCREENS]) for width in widths("places-screen-"))
              or ('<p class="note">The seven screens are not made by this build: %s, and %s; see %s.</p>'
                  % tuple(html.escape(x) for x in (FINISH_ELSEWHERE[0][2], FINISH_ELSEWHERE[1][2], GATE_SCREENS))
                  if finish else '<p class="missing">The seven screens: not produced in this run.</p>')) +
             ('<p class="note">The 440-pt seven screens: %s; see Places-Correction-Screens.zip.</p>'
              % html.escape(SWEEP_ELSEWHERE[0][2]) if sweep else "")),
            ("Eligibility: every intent at every venue (XCTest, direct launches)",
             '<p class="note">Not made by this build: %s; see %s.</p>' % (html.escape(FINISH_ELSEWHERE[2][2]), GATE_SCREENS)
             if finish and not any(k.startswith("places-eligibility-") for k in shots) else
             "".join(row(*[shot("places-eligibility-%s-%s-fixture" % (key, intent), "%s at %s" % (intent.title(), name))
                           for key, name, _ in VENUES]) for intent in INTENTS)),
            ("The journey, step by step (XCTest, real route)",
             row(*[shot(key, caption) for key, caption in JOURNEY])),
            ("Routes, the band, the Birthday gate, relaunch, interruptions and Reduce Motion",
             row(*[shot(key, caption) for key, caption in OTHERS])),
            ("Largest accessibility text size (direct launches; each width in turn)",
             (row(*[img(v, k.replace("places-largest-text-", "").replace("-fixture", "")) for k, v in sorted(
                 ((k, v) for k, v in shots.items() if k.startswith("places-largest-text-")),
                 key=lambda item: (-int(re.search(r"-(\d+)pt-", item[0]).group(1)) if re.search(r"-(\d+)pt-", item[0]) else 0,
                                   item[0]))])
              or '<p class="missing">Largest-text captures: not produced in this run.</p>') +
             ('<p class="note">The smaller iPhone\'s largest text (P11) runs in recovery build 3 (gate_finish) as an extra; '
              'see %s.</p>' % GATE_SCREENS if finish else "")),
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
    # The sweep's S rows (Signal and Guest List tests) attach captures of their own names; every one is
    # shown, as the signal scope's package showed them.
    def s_row(key):
        # By the test that attached it; a capture whose test is unknown counts only if it is neither a
        # Places capture nor a scroll helper's failure screen (which belongs to the P row that failed). In
        # sweep_finish the Guest List's tests are B rows, so only Signal's are S rows.
        test = shot_tests.get(key, "?")
        if finish:
            return test.startswith("SignalReviewTests")
        return test.startswith(("SignalReviewTests", "GuestListReviewTests")) or (
            test == "?" and not key.startswith(("places-", "scroll-")))
    signal_shots = sorted((k, v) for k, v in shots.items() if s_row(k)) if sweep or finish else []
    regression_shots = sorted(((shot_tests.get(k, "?").split("/")[0], k), v) for k, v in shots.items()
                              if shot_tests.get(k, "?").startswith(REGRESSION_CLASSES)) if finish else []
    if sweep:
        sections.append(("The S rows of this build (S3-S6, S8-S10, S12 and S13 on main; S15 and S16 on the smaller "
                         "iPhone): every capture they attached",
                         row(*[img(v, k) for k, v in signal_shots]) if signal_shots
                         else '<p class="missing">The S rows attached no capture in this run.</p>'))
    if finish:
        sections.append(("The S rows of this build (S9, S10, S12 and S13 on the iPhone 17 Pro Max): every capture they "
                         "attached",
                         row(*[img(v, k) for k, v in signal_shots]) if signal_shots
                         else '<p class="missing">The S rows attached no capture in this run.</p>'))
        sections.append(("The regression rows of this build (M1-M3 on the iPhone 17 Pro Max; M4-M13, B1, B10-B13 and B15 "
                         "on device B, its clone): every capture they attached, by test class",
                         row(*[img(v, "%s: %s" % (cls, k)) for (cls, k), v in regression_shots]) if regression_shots
                         else '<p class="missing">The regression rows attached no capture in this run.</p>'))
        # Anything this page does not show yet (a scroll helper's failure screen, a capture of an unknown test).
        shown = "".join(content for _, content in sections)
        leftover = sorted((k, v) for k, v in shots.items() if 'src="%s"' % v not in shown)
        if leftover:
            sections.append(("Every other capture of this build", row(*[img(v, k) for k, v in leftover])))
    else:
        leftover = []
    # Every execution of the sweep or sweep_finish, by row: the rows under their earlier IDs, and the earlier
    # row each counts as (docs/verification/places-recovery-coverage.tsv; the sweep, planned before
    # build 2, is not in it: its P and S rows count as the places and signal rows of the same ID).
    execution_section = ""
    if sweep or finish:
        counts_as = {}
        for entry in coverage_lines(root):
            if entry["scope"] == scope:
                counts_as.setdefault(entry["row"], []).append(entry["target"])
        counts_as = {order: ", ".join(names) for order, names in counts_as.items()}
        if sweep:
            counts_as = {}
            for key in (r[1] for r in (line.split("\t") for line in read(os.path.join(out, "manifest-rows.tsv")).splitlines())
                        if len(r) > 1):
                counts_as[key] = ("places:" if key.startswith("P") else "signal:") + key
        tsv_lines = read(os.path.join(out, "executions.tsv")).splitlines()
        header = tsv_lines[0].split("\t") if tsv_lines else []
        executed = [dict(zip(header, line.split("\t"))) for line in tsv_lines[1:] if line.strip()]
        if not executed:
            missing.append("results/executions.tsv (every execution by row)")
        execution_rows = "".join(
            "<tr>%s</tr>" % "".join("<td>%s</td>" % html.escape(c) for c in (
                e.get("order", ""), counts_as.get(e.get("order", ""), "-"), e.get("device", ""), e.get("udid", ""),
                e.get("run", ""), e.get("test", ""), e.get("kind", ""), e.get("outcome", ""), e.get("seconds", ""),
                e.get("failure", "")))
            for e in executed) or '<tr><td colspan="10">executions.tsv was not produced in this run.</td></tr>'
        tally = ", ".join("%d %s rows" % (n, letter) for letter, n in (
            (letter, sum(1 for e in executed if e.get("order", "").startswith(letter))) for letter in "PSMB") if n)
        execution_section = (
            "<h2>Every execution in this build, by row (%s; retries off)</h2>"
            "<table><tr><th>Row</th><th>Counts as</th><th>Device</th><th>UDID</th><th>Run</th><th>Test</th><th>Kind</th>"
            "<th>Outcome</th><th>Seconds</th><th>Failure</th></tr>%s</table>" % (tally or "none", execution_rows))
    if places and not finish and not widths("places-screen-"):
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
%s
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
        deviation_rows, manifest_rows, test_rows, execution_section, html.escape("\n\n".join(notes) or "none"),
        html.escape(verdict),
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
                  "the full verdict (results/verdict.txt) are in %s.zip. Automated checks are not visual "
                  "approval.\n" % (headline, head, build_label, simulator.get("device_name", "an unrecorded simulator"),
                                   simulator.get("runtime_name", "an unrecorded runtime"), title))
        if sweep:
            readme += ("P7 (the seven screens at 440 pt) and P8 (Back routes) run in the correction build as C9 and C15, "
                       "and S1, S2, S7, S11 and S14 as C4-C8, on the same commit; their screens are in "
                       "Places-Correction-Screens.zip. Signal-rows-* files are the captures attached by this build's S "
                       "rows (SignalReviewTests and GuestListReviewTests), each under the name its test gave it: "
                       "'journey' in a name means the real route, 'fixture' a direct launch.\n")
        if finish:
            readme += ("This is recovery build 4 (sweep_finish). P7 (the seven screens at 440 pt), P9, P10, P11, P12 and "
                       "P13 (the smaller iPhone) are made by recovery build 3 (gate_finish; %s), P8 (Back routes) by "
                       "%s as C15 (%s); the files named *.IN-GATE-BUILD.txt and *.IN-CORRECTION-BUILD.txt say which. "
                       "Signal-rows-* files are the captures attached by this build's S rows (SignalReviewTests), "
                       "Regression-rows-<test class>-* those of its M and B rows (the Birthday, Wristband, Pass, Guest "
                       "List and Welcome tests), each under the name its test gave it: 'journey' in a name means the "
                       "real route, 'fixture' a direct launch. Other-capture-* files are any other capture.\n"
                       % (GATE_SCREENS, BUILD2_NOTE, CORRECTION_SCREENS))
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
        for key, _ in signal_shots:
            screens.append((key, "Signal-rows-%s-XCTest.png" % key))
        for (cls, key), _ in regression_shots:
            screens.append((key, "Regression-rows-%s-%s-XCTest.png" % (cls, key)))
        for key, _ in leftover:
            if key not in {k for k, _ in screens}:
                screens.append((key, "Other-capture-%s-XCTest.png" % key))
        with zipfile.ZipFile(os.path.join(artifacts, archive_prefix + "-Screens.zip"), "w", zipfile.ZIP_STORED) as bundle:
            bundle.writestr("README.txt", readme)
            for key, target in screens:
                name = shots.get(key)
                if name and name in sources:
                    bundle.write(sources[name], target)
                elif elsewhere(key):
                    what, archive = elsewhere(key)
                    bundle.writestr(target + (".IN-CORRECTION-BUILD.txt" if archive == CORRECTION_SCREENS
                                              else ".IN-GATE-BUILD.txt"),
                                    "Not made by this build: %s (see %s).\n" % (what, archive))
                else:
                    bundle.writestr(target + ".MISSING.txt", "Not produced in this run.\n")
            if notes:
                bundle.writestr("Notes-attached-by-the-tests.txt", "\n\n".join(notes) + "\n")
        made.append(archive_prefix + "-Screens.zip")
        if compact:
            reencoded = compact_note == "RE-ENCODED"
            if reencoded:
                inner = archive_prefix + "-walkthrough-compact-RE-ENCODED-TRIMMED.mp4"
                label = ("Compact walkthrough: RE-ENCODED and TRIMMED to the app (%s; %s). A half-size AVFoundation "
                         "re-encode, not the original encoding. The unedited recording is in "
                         "%s-walkthrough-original.zip.\n" % (compact_info.get("method", "AVFoundation export"),
                                                             compact_info.get("trim", "trim not recorded"), archive_prefix))
            else:
                inner = archive_prefix + "-walkthrough-FALLBACK-COPY-not-re-encoded-not-trimmed.mp4"
                label = ("Compact walkthrough: %s. The re-encode did not complete, so this is a plain copy of the "
                         "unedited recording: not re-encoded and not trimmed.\n" % compact_note)
            with zipfile.ZipFile(os.path.join(artifacts, archive_prefix + "-walkthrough-compact.zip"), "w",
                                 zipfile.ZIP_STORED) as bundle:
                bundle.writestr("README.txt", readme + label)
                bundle.write(sources[compact], inner)
            made.append(archive_prefix + "-walkthrough-compact.zip")
            if reencoded:
                shutil.copyfile(sources[compact], os.path.join(artifacts, archive_prefix + "-walkthrough-compact.mp4"))
                made.append(archive_prefix + "-walkthrough-compact.mp4")
        if original:
            with zipfile.ZipFile(os.path.join(artifacts, archive_prefix + "-walkthrough-original.zip"), "w",
                                 zipfile.ZIP_STORED) as bundle:
                bundle.writestr("README.txt", readme + "The unedited simulator recording of the real journey.\n")
                bundle.write(sources[original], archive_prefix + "-walkthrough-original.mp4")
            made.append(archive_prefix + "-walkthrough-original.zip")
    for name in made:
        path = os.path.join(artifacts, name)
        open(path + ".sha256", "w").write("%s  %s\n" % (sha256(path), name))
        print("%s sha256 %s" % (name, sha256(path)))
    return 1 if broken else 0


CORRECTION_BASE = "0fb4e467d70ca00a5cf5b1e8e48a671ec3c87517"
CORRECTION_TESTED = "ea14c0011fa87b28c956640fa95d4eebc2674e7b"
CORRECTION_DEVIATIONS = (
    ("Signal to Places and back", "Accepted for the prototype: native push and pop at the Signal–Places boundary, not "
     "Figma's 240 ms dissolve. Recorded as a deviation, not a match."),
    ("The ticket's expansion", "Accepted for the prototype: the scene, the name and the kind move; the lower parts of the "
     "card cross-fade. Recorded as a deviation, not a match."),
    ("One-stage back gestures", "Places shows its stages inside one navigation destination, so the expansion can play. "
     "While Places is on screen, a swipe from the leading edge is handled by Places itself and goes back exactly one stage, "
     "as the screen's Back controls do. The navigation stack's own pans and scroll views wait for it to fail. On a detail or "
     "the explanation, iOS 26's swipe-from-anywhere pop is held off, so no swipe skips to Signal. From browsing, the swipe "
     "ends in the stack's native pop to Signal. Outside Places nothing changes."),
    ("The browse ticket's accessibility", "The ticket's parts (name, kind, intents, schedule) read on their own, and "
     "View place is a real button (VoiceOver: “View place”). Before the correction the whole ticket was one element. "
     "The card itself still opens the detail when tapped. VoiceOver itself was not run."),
    ("VoiceOver's escape gesture", "Each Places stage is one accessibility container (places.screen) that owns the escape "
     "action, and escape goes back one stage, as the screen's Back controls do. VoiceOver does not run in the Simulator, "
     "so the escape itself is unverified here: it is a manual check on a device."),
)


def package_correction(root, out, artifacts, title, prefix, scope, entries, missing, shots, shot_tests, notes, board,
                       original, add):
    """The correction scope's downloads and gate_finish's (see the module's documentation)."""
    gate = scope == "gate_finish"
    out_zip = os.path.join(artifacts, title + ".zip")
    before_dir = os.path.join(root, "docs/verification/places-correction-before")
    try:
        provenance = json.load(open(os.path.join(before_dir, "provenance.json"), encoding="utf-8"))
    except (OSError, ValueError):
        provenance = {"files": {}}
    before = {}
    for name, info in sorted(provenance.get("files", {}).items()):
        before[name] = (add("before/" + name, os.path.join(before_dir, name)), info.get("caption", name),
                        info.get("from", ""), info.get("from_sha256", ""))
    add("before/provenance.json", os.path.join(before_dir, "provenance.json"))

    verdict = read(os.path.join(out, "verdict.txt")) or "No verdict was produced in this run."
    headline = next((l for l in verdict.splitlines() if l.startswith("AUTOMATED VERDICT")), "AUTOMATED VERDICT: not produced")
    head = kv(os.path.join(out, "source-checkpoint.txt")).get("git_head", "unknown")
    build_id = os.environ.get("CM_BUILD_ID", "")
    build_label = ("Codemagic build %s" % build_id) if build_id else "a simulator run outside Codemagic"

    def git(*args):
        return git_in(root, *args) or ""

    changed = git("diff", "--name-status", CORRECTION_BASE, "HEAD") or "unavailable (git)"
    if git("rev-parse", "HEAD"):
        changed_product = git("diff", "--name-status", CORRECTION_TESTED, "HEAD", "--", "Proximeet", "ProximeetDomain",
                              "ProximeetUITests", "Proximeet.xcodeproj") or "none"
        changed_since_first = git("diff", "--name-status", FIRST_CORRECTION_COMMIT, "HEAD", "--", "Proximeet",
                                  "ProximeetDomain", "ProximeetUITests", "Proximeet.xcodeproj") or "none"
    else:
        changed_product = changed_since_first = "unavailable (git)"
    changed_since_build2 = product_changes(root)

    # Every row of the manifest, and what this build executed of it, by test and device class.
    manifest = [line.rstrip("\n").split("\t") for line in open(os.path.join(root, "docs/verification/places-review-manifest.tsv"),
                                                              encoding="utf-8") if line.strip() and not line.startswith("#")]
    executions = []
    tsv = os.path.join(out, "executions.tsv")
    if os.path.isfile(tsv):
        lines = read(tsv).splitlines()
        header = lines[0].split("\t") if lines else []
        executions = [dict(zip(header, line.split("\t"))) for line in lines[1:] if line.strip()]
    # Only rows that really ran: an optional row left unrun for time has a "not run" outcome. A row of
    # this scope that is an earlier test (correction: C9 = P7, C15 = P8, C4-C8 = S1, S2, S7, S11, S14;
    # gate_finish: those on main, and its extras under their own IDs) executes that earlier row too: the
    # same test on the same device class (main and its clone b are one), in the same kind of run (a
    # recorded "journey" run keeps full holds, every other run short holds). Required and extra rows
    # count, as in scripts/places_recovery_reconcile.py; a diagnostic or repeat row stands for nothing.
    kinds = {}
    for scope_name, order, device, run, bundle, seconds, test, kind in manifest:
        if scope_name == scope:
            kinds[order] = (run, kind)
    ran = {}
    for e in executions:
        run, kind = kinds.get(e.get("order", ""), (e.get("run", ""), e.get("kind", "")))
        if kind in ("required", "extra") and e.get("outcome") and not e["outcome"].startswith("not run") \
                and e["outcome"] != "skipped":
            ran[(e.get("test", ""), CLASS.get(e.get("device", ""), "?"), run == "journey")] = (
                e.get("order", "?"), kind, e["outcome"])
    # Where each row is due otherwise: docs/verification/places-recovery-coverage.tsv.
    due = {}
    for entry in coverage_lines(root):
        due[entry["target"]] = ("pending: no recovery build runs it" if entry["scope"] == "pending" else
                                "recovery build %s (%s) as %s, run %s (%s)" % (entry["build"], entry["scope"], entry["row"],
                                                                              entry["run"], entry["kind"]))
    earlier_rows, correction_rows = [], []
    for scope_name, order, device, run, bundle, seconds, test, kind in manifest:
        if scope_name == "correction" and kind == "required":
            here = ran.get((test.replace("/", "."), CLASS.get(device, "?"), run == "journey"))
            status = ("executed in this build as %s (%s): %s" % here if here else
                      "not executed in this build; %s" % due.get("correction:" + order, "not in the coverage file"))
            correction_rows.append((order, device, test.replace("/", "."), status))
            continue
        if scope_name not in ("places", "signal", "regressions"):
            continue
        here = ran.get((test.replace("/", "."), CLASS.get(device, "?"), run == "journey"))
        if here:
            status = "executed in this build as %s (%s; the same test on the same device class): %s" % here
        else:
            status = "not executed in this build; due in %s" % due.get("%s:%s" % (scope_name, order),
                                                                      "no build of the recovery (see the coverage file)")
        earlier_rows.append((scope_name, order, device, test.replace("/", "."), kind, status))
    unrun = [r for r in earlier_rows if r[5].startswith("not executed") and r[4] == "required"]
    covered_here = [r for r in earlier_rows if r[5].startswith("executed") and r[4] == "required"]

    def img(name, caption):
        if not name:
            return '<p class="missing">%s: not produced in this run.</p>' % html.escape(caption)
        return '<figure><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>' % (
            name, html.escape(caption), html.escape(caption))

    def made_in_build2(key):
        # gate_finish: the captures of C10-C15, which ran on the smaller iPhone in recovery build 2 only.
        width = re.search(r"-(\d+)pt-", key)
        return gate and (key.startswith(("correction-walkthrough-", "correction-gesture-")) or
                         (key.startswith("correction-") and bool(width) and width.group(1) != "440") or
                         key in ("places-back-to-places-later-fixture", "places-reentry-after-card-later-fixture"))

    def shot(key, caption):
        if key not in shots and made_in_build2(key):
            return '<p class="note">%s: made by %s; see that build\'s %s.</p>' % (
                html.escape(caption), html.escape(BUILD2_NOTE), CORRECTION_SCREENS)
        return img(shots.get(key), caption)

    def row(*cells):
        return '<div class="row">%s</div>' % "".join(cells)

    def before_img(key):
        name, caption, source, digest = before.get(key, (None, key, "", ""))
        return img(name, "BEFORE (build 6ab8639c, %s): %s" % (source or "missing", caption))

    def approved(index, caption):
        if not board:
            return '<p class="missing">Approved reference missing.</p>'
        return ('<figure><div class="crop" style="background-image:url(%s);background-position:-%dpx -129px"></div>'
                '<figcaption>%s</figcaption></figure>') % (board, [30, 390, 750][index], html.escape(caption))

    if gate:
        # This build's correction captures are the iPhone 17 Pro Max's (440 pt); the smaller iPhone's
        # (390 pt, the iPhone 17e) are recovery build 2's.
        widths = ["440", "390"]
    else:
        widths = sorted({m.group(1) for k in shots for m in [re.search(r"-(\d+)pt-", k)] if m}, key=int, reverse=True)
    venues = (("common-ground", "Common Ground"), ("afterglow", "Afterglow"), ("fieldwork", "Fieldwork"))
    footer_rows = "".join(
        row(*[shot("correction-footer-%s-%s-%spt-fixture" % (key, size, width), "%s, %s text, %s pt (FIXTURE)" % (name, size, width))
              for key, name in venues])
        for size in ("normal", "largest") for width in widths)
    gestures = row(*[shot(k, k.replace("correction-", "").replace("-fixture", "").replace("-", " ")) for k in sorted(shots)
                     if k.startswith("correction-gesture-")]) + \
        row(*[shot(k, k.replace("correction-", "").replace("-", " ")) for k in sorted(shots)
              if k.startswith("correction-walkthrough-")])
    if gate:
        gestures = ('<p class="note">C10 (the recorded correction walkthrough) and C11 (back gestures and controls, with a '
                    'cancelled swipe) run on the smaller iPhone only; both passed in %s. Their captures are in that '
                    'build\'s %s and its recording in its Places-Correction-walkthrough.zip; they are not rerun here.</p>'
                    % (html.escape(BUILD2_NOTE), CORRECTION_SCREENS))
    sections = [
        ("Before and after: the footer at the largest text (Fieldwork)",
         row(before_img("before-footer-largest-440pt.png"),
             shot("correction-footer-fieldwork-largest-440pt-fixture", "AFTER, 440 pt: the whole schedule above View place")) +
         row(before_img("before-footer-largest-390pt.png"),
             shot("correction-footer-fieldwork-largest-390pt-fixture", "AFTER, 390 pt: the whole schedule above View place"))),
        ("Before and after: a detail opens at its beginning (largest text)",
         row(before_img("before-detail-entry-largest-440pt.png"),
             shot("correction-footer-fieldwork-opened-largest-440pt-fixture",
                  "AFTER, 440 pt: Fieldwork opened by View place from scrolled browsing, at its beginning"),
             shot("correction-entry-browse-scrolled-440pt-largest-fixture", "AFTER, 440 pt: Now's browsing scrolled to View place"),
             shot("correction-entry-detail-start-440pt-largest-fixture", "AFTER, 440 pt: Common Ground's detail at its beginning")) +
         row(before_img("before-detail-entry-largest-390pt.png"),
             shot("correction-footer-fieldwork-opened-largest-390pt-fixture",
                  "AFTER, 390 pt: Fieldwork opened by View place from scrolled browsing, at its beginning"),
             shot("correction-entry-browse-scrolled-390pt-largest-fixture", "AFTER, 390 pt: Now's browsing scrolled to View place"),
             shot("correction-entry-detail-start-390pt-largest-fixture", "AFTER, 390 pt: Common Ground's detail at its beginning"))),
        ("Before and after: Upcoming on the 390-pt phone (default text)",
         row(before_img("before-footer-upcoming-normal-390pt.png"),
             shot("correction-walkthrough-upcoming-initial", "AFTER (recorded run): View place below the fold at first"),
             shot("correction-walkthrough-upcoming-footer-scrolled", "AFTER: scrolled, the whole button above the Back area"),
             shot("correction-walkthrough-fieldwork-detail-start", "AFTER: a real tap on it opened Fieldwork at its beginning"))),
        ("Every footer (the approved board's Now for reference)",
         row(approved(0, "Approved: Now (58:480), 440 pt")) + (footer_rows or '<p class="missing">No footer captures.</p>') +
         row(*[shot("correction-footer-fieldwork-opened-%s-%spt-fixture" % (size, width),
                    "View place tapped: Fieldwork, %s text, %s pt" % (size, width))
               for size in ("normal", "largest") for width in widths])),
        ("Where a stage starts, and the way back (largest text)",
         row(*[shot("correction-entry-%s-%spt-largest-fixture" % (state, width), "%s, %s pt" % (state.replace("-", " "), width))
               for width in widths for state in ("detail-end", "explanation-start", "explanation-end", "back-to-now")]) +
         row(*[shot("correction-footer-back-to-upcoming-largest-%spt-fixture" % width, "Back to places: Upcoming, %s pt" % width)
               for width in widths])),
        ("Back by gesture and by control", gestures),
        ("The five Signal and interaction tests whose endpoint changed",
         row(*[shot(k, k) for k in ("signal-journey-continue-places", "signal-continue-places-fixture", "06-places",
                                    "08-reduced-motion-places")])),
        ("P7 and P8 of the places scope, run as C9 (the seven screens, 440 pt) and C15 (Back routes, smaller iPhone)",
         row(*[shot("places-screen-%s-social-440pt-fixture" % key, "C9: %s, 440 pt (FIXTURE)" % label)
               for key, label in SCREENS]) +
         row(shot("places-back-to-places-later-fixture", "C15: Back to places, Later kept (FIXTURE)"),
             shot("places-reentry-after-card-later-fixture", "C15: back to the Guest List card and forward again, Later kept "
                                                             "(FIXTURE)"))),
    ]
    if original:
        sections.insert(0, ("The recorded correction walkthrough (smaller iPhone, unedited)",
                            '<figure><video src="%s" controls muted playsinline preload="metadata"></video><figcaption>'
                            'Original simulator recording, unedited. It starts before the app opens.</figcaption></figure>' % original))
    elif gate:
        sections.insert(0, ("No recording in this build",
                            '<p class="note">gate_finish records nothing. The recovery\'s walkthrough is C10, recorded on the '
                            'smaller iPhone in %s: its Places-Correction-walkthrough.zip.</p>' % html.escape(BUILD2_NOTE)))
    leftover = []
    if gate:
        # The extras (S3-S6 and S8 on main; P9-P13, S15 and S16 on the smaller iPhone) and anything else this
        # page does not show yet, by the test that attached it.
        shown = "".join(content for _, content in sections)
        leftover = sorted((k, v) for k, v in shots.items() if 'src="%s"' % v not in shown)
        sections.append(("The extras of this build, and every other capture (S3-S6 and S8 on the iPhone 17 Pro Max; "
                         "P9-P13, S15 and S16 on the smaller iPhone; each started only when its bound plus 60 s was left)",
                         row(*[img(v, "%s (%s)" % (k, shot_tests.get(k, "?").split("/")[0])) for k, v in leftover])
                         if leftover else '<p class="note">No other capture in this run (see the executions below for '
                                          'whether each extra ran).</p>'))
    body = "".join("<h2>%s</h2>%s" % (html.escape(t), c) for t, c in sections)
    def kind_label(e):
        if e.get("kind") == "diagnostic" or (e.get("kind") == "extra" and e.get("run", "").startswith("probe_")):
            return "diagnostic (optional; never part of the verdict)"
        return e.get("kind", "")

    run_rows = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % html.escape(kind_label(e) if k == "kind" else e.get(k, ""))
                                                for k in ("order", "device", "udid", "run", "test", "kind", "outcome",
                                                          "seconds", "failure"))
                       for e in executions)
    earlier_table = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % html.escape(c) for c in r) for r in earlier_rows)
    correction_table = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % html.escape(c) for c in r) for r in correction_rows)
    deviation_rows = "".join("<tr><td>%s</td><td>%s</td></tr>" % (html.escape(a), html.escape(b)) for a, b in CORRECTION_DEVIATIONS)
    if gate:
        heading = "Places: the correction gate, finished (recovery build 3, gate_finish)"
        intro = ("%s. Source <code>%s</code>. This is recovery build 3 (gate_finish) of the recovery after the Places "
                 "correction. Recovery build 2 (Codemagic <code>%s</code>, scope correction, on <code>%s</code>) passed C10-C15 "
                 "on the smaller iPhone; on the iPhone 17 Pro Max every run exited 65 before any test started (the test runner "
                 "failed to initialize for UI testing). So this build runs C1-C9 on the iPhone 17 Pro Max, with the "
                 "correction scope's row IDs, tests, runs and bounds, and, as extras (each started only when its bound plus "
                 "60 s was left; if one ran it had to pass), S3-S6 and S8 on main and P9-P13, S15 and S16 on the smaller "
                 "iPhone. <b>C10-C15 are build 2's</b>: they are not rerun here, and every capture they made (the 390-pt "
                 "correction screens, the gestures, the walkthrough, C15's Back routes) is named below as build 2's. Recovery "
                 "build 4 (sweep_finish) runs P1-P6, S9, S10, S12, S13, M1-M13, B1, B10-B13 and B15; B2-B9 and the optional "
                 "B14 run in no recovery build (pending). scripts/places_recovery_reconcile.py reconciles the builds row by "
                 "row, counting only builds whose product and test files equal <code>%s</code>'s. Captures named "
                 "signal-journey-* come from Signal's real-route test, <code>SignalReviewTests.testWalkthroughRealJourney"
                 "</code> (unrecorded); every correction capture is a direct launch (FIXTURE) through the same gates. BEFORE "
                 "images are 1× copies of build 6ab8639c's captures (before/provenance.json names each original and its "
                 "SHA-256)." % (html.escape(build_label), html.escape(head), BUILD2_ID, REFERENCE[:12], REFERENCE[:12]))
    else:
        heading = "Places: targeted correction"
        intro = ("%s. Source <code>%s</code>, based on <code>%s</code>. Before this correction, <code>%s</code> passed the "
                 "places scope only (build 6ab8639c, 13 executions); the earlier chapters' 43 executions last passed at "
                 "1085af3d and b06707ec. This is the correction gate, run as recovery build 2 (Codemagic %s, on "
                 "<code>%s</code>): C10-C15 passed there on the smaller iPhone, and on the iPhone 17 Pro Max every run exited "
                 "65 before any test started (the test runner failed to initialize for UI testing). Recovery builds 3 "
                 "(gate_finish: C1-C9 and extras) and 4 (sweep_finish) finish the recovery, and "
                 "scripts/places_recovery_reconcile.py reconciles the builds row by row. It executes P7 as C9, P8 as C15 and "
                 "S1, S2, S7, S11, S14 as C4-C8, listed below by test and device. The first correction build, 6ab8adb4 on "
                 "<code>%s</code>, passed 14 of its 15 required rows (C12 failed); it counts toward nothing here, and the "
                 "product files changed since its commit are listed below. Of the scroll diagnostic, only C17 (smaller "
                 "iPhone) ran in that build; C16 (iPhone 17 Pro Max) was left unrun for time. Neither is in the manifest any "
                 "more. The correction's captures come from direct launches (FIXTURE) through the same gates. Captures named "
                 "signal-journey-* come from Signal's real-route test, <code>SignalReviewTests.testWalkthroughRealJourney"
                 "</code> (onboarding → Signal → Places, on the iPhone 17 Pro Max, unrecorded). BEFORE images are 1× copies "
                 "of build 6ab8639c's captures (before/provenance.json names each original and its SHA-256)."
                 % (html.escape(build_label), html.escape(head), CORRECTION_BASE, CORRECTION_TESTED, BUILD2_ID,
                    REFERENCE[:12], FIRST_CORRECTION_COMMIT[:12]))
    build2_block = ("<h2>Product and test files changed since %s, recovery build 2's commit (none: the product and "
                    "the tests are build 2's)</h2><pre>%s</pre>" % (REFERENCE[:12], html.escape(changed_since_build2))
                    if gate else "")
    page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>%s</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;margin:24px;background:#111;color:#eee}
h1{font-size:22px}h2{font-size:17px;margin-top:32px;border-top:1px solid #333;padding-top:16px}
.row{display:flex;flex-wrap:wrap;gap:20px;margin-bottom:16px}figure{margin:0}
figcaption{color:#aaa;font-size:13px;max-width:330px}
img,video{width:330px;max-width:100%%;border:1px solid #333;border-radius:8px;background:#000}
.crop{width:330px;height:717px;border:1px solid #333;border-radius:8px;background-repeat:no-repeat;background-size:1110px 1252.5px}
table{border-collapse:collapse;max-width:1200px}td,th{border:1px solid #333;padding:5px 7px;vertical-align:top;font-size:12px;text-align:left}
pre{white-space:pre-wrap;background:#1b1b1b;padding:12px;border-radius:8px;font-size:12px}.missing{color:#f99}
.note{color:#ccc;max-width:820px}</style></head><body>
<h1>%s</h1>
<p><b>%s</b></p>
<p class="note">%s</p>
%s
<h2>Files changed since %s</h2><pre>%s</pre>
<h2>Product and test files changed since the tested %s</h2><pre>%s</pre>
<h2>Product and test files changed since %s, the first correction build's commit (build 6ab8adb4)</h2><pre>%s</pre>
%s
<h2>Every execution in this build (retries off)</h2><table><tr><th>Order</th><th>Device</th><th>UDID</th><th>Run</th><th>Test</th>
<th>Kind</th><th>Outcome</th><th>Seconds</th><th>Failure</th></tr>%s</table>
<h2>The correction's rows C1-C15: executed here, or where they are due</h2>
<table><tr><th>Order</th><th>Device</th><th>Test</th><th>In this build</th></tr>%s</table>
<h2>Earlier coverage: %d required earlier executions executed here; %d not executed here (due in another recovery build, or pending)</h2>
<table><tr><th>Scope</th><th>Order</th><th>Device</th><th>Test</th><th>Kind</th><th>In this build</th></tr>%s</table>
<h2>Deviations and decisions, recorded</h2><table><tr><th>What</th><th>How</th></tr>%s</table>
<h2>Notes attached by the tests</h2><pre>%s</pre>
<h2>Result</h2><pre>%s</pre>
<p>Unsigned simulator app (simulator only): %s</p>
<p>Details: %s | <a href="SHA256SUMS.txt">SHA256SUMS.txt</a></p>
<p class="missing">%s</p>
</body></html>""" % (
        html.escape("Places gate finish" if gate else "Places correction"), html.escape(heading), html.escape(headline),
        intro, build2_block, CORRECTION_BASE[:12], html.escape(changed), CORRECTION_TESTED[:12], html.escape(changed_product),
        FIRST_CORRECTION_COMMIT[:12], html.escape(changed_since_first), body, run_rows, correction_table,
        len(covered_here), len(unrun), earlier_table, deviation_rows, html.escape("\n\n".join(notes) or "none"),
        html.escape(verdict),
        " ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries if n.startswith("app/") and n.endswith(".zip"))
        or "not produced",
        " | ".join('<a href="%s">%s</a>' % (n, html.escape(n)) for n, _ in entries
                   if n.startswith(("results/", "logs/")) or (n.startswith("xctest/") and n.endswith((".txt", ".json")))),
        ("Not produced in this run: " + ", ".join(missing)) if missing else "")

    targets = set(re.findall(r'(?:src|href)="([^"#:]+)"', page)) | set(re.findall(r"url\(([^)]+)\)", page))
    packed = {n for n, _ in entries} | {"SHA256SUMS.txt"}
    broken = sorted(t for t in targets if t not in packed)
    if broken:
        print("BROKEN relative links in index.html: " + ", ".join(broken))
    sums = "".join("%s  %s\n" % (sha256(source), name) for name, source in entries)
    os.makedirs(artifacts, exist_ok=True)
    with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED) as bundle:
        bundle.writestr(title + "/index.html", page)
        bundle.writestr(title + "/SHA256SUMS.txt", sums)
        for name, source in entries:
            bundle.write(source, title + "/" + name)
    print("%s.zip: %d files, %d relative links checked, %d broken%s" % (
        title, len(entries) + 2, len(targets), len(broken), ("; missing: " + ", ".join(missing)) if missing else ""))
    open(os.path.join(out, "package-links.txt"), "w").write(
        "links=%d\nbroken=%s\nmissing=%s\nearlier_required_executed_here=%d\nunrun_required_earlier=%d\n" % (
            len(targets), ",".join(broken) or "none", ",".join(missing) or "none", len(covered_here), len(unrun)))

    sources = dict(entries)
    if gate:
        readme = ("%s\nPlaces gate finish (recovery build 3), source %s, %s. The correction screens here are the iPhone 17 Pro "
                  "Max's (440 pt), each a direct launch (FIXTURE) through the same gates; files named XCTest-journey come "
                  "from a real route. C10-C15 are %s: their screens (the 390-pt correction screens, the gestures, the "
                  "walkthrough, C15's Back routes) are in that build's %s, not here. The extras' captures (S3-S6 and S8 "
                  "on main; P9-P13, S15 and S16 on the smaller iPhone) are here under the names their tests gave them. "
                  "BEFORE-* files are 1x copies of build 6ab8639c's captures, named in before/provenance.json of %s.zip. "
                  "Automated checks are not visual approval.\n" % (headline, head, build_label, BUILD2_NOTE,
                                                                 CORRECTION_SCREENS, title))
    else:
        readme = ("%s\nPlaces correction, source %s, %s. Every correction screen is a direct launch (FIXTURE) through the "
                  "same gates; files named XCTest-journey come from Signal's real onboarding route. BEFORE-* files are 1x copies of "
                  "build 6ab8639c's captures, named in before/provenance.json of Places-Correction-Review.zip. Automated checks are "
                  "not visual approval.\n" % (headline, head, build_label))
    made = [title + ".zip"]
    screens_zip = prefix + "-Screens.zip"
    with zipfile.ZipFile(os.path.join(artifacts, screens_zip), "w", zipfile.ZIP_STORED) as bundle:
        bundle.writestr("README.txt", readme)
        for key in sorted(shots):
            if gate:
                label = ("XCTest-journey" if "journey" in key else "XCTest-FIXTURE-direct-launch"
                         if key.endswith("fixture") or key.startswith("correction-") else "XCTest")
            else:
                label = "XCTest-journey" if key.startswith("signal-journey-") else "XCTest-FIXTURE-direct-launch"
            bundle.write(sources[shots[key]], "%s-%s%s" % (key, label, os.path.splitext(shots[key])[1] or ".png"))
        for name, (packed_name, caption, source, digest) in sorted(before.items()):
            if packed_name:
                bundle.write(sources[packed_name], "BEFORE-build-6ab8639c-" + name)
        if notes:
            bundle.writestr("Notes-attached-by-the-tests.txt", "\n\n".join(notes) + "\n")
    made.append(screens_zip)
    if original:
        with zipfile.ZipFile(os.path.join(artifacts, "Places-Correction-walkthrough.zip"), "w", zipfile.ZIP_STORED) as bundle:
            bundle.writestr("README.txt", readme + "The unedited simulator recording of the correction walkthrough on the "
                            "smaller iPhone: Upcoming scrolled to View place, a real tap on it, back swipes (one not completed, "
                            "then completed ones, one stage each) from Fieldwork's detail, the explanation, Common Ground's "
                            "detail and browsing to Signal. No compact re-encode was made on the Mac. It starts before the "
                            "app opens; a simulator recording is not evidence of on-device smoothness.\n")
            bundle.write(sources[original], "Places-Correction-walkthrough-original.mp4")
        made.append("Places-Correction-walkthrough.zip")
    for name in made:
        path = os.path.join(artifacts, name)
        open(path + ".sha256", "w").write("%s  %s\n" % (sha256(path), name))
        print("%s sha256 %s" % (name, sha256(path)))
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

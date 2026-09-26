#!/usr/bin/env python3
"""Proximeet Signal regression correction: build/artifacts/Signal-Regression-Recovery.zip.

    python3 scripts/signal_regression_recovery.py ROOT OUT ARTIFACTS

Run by `SIGNAL_REVIEW_SCOPE=regressions bash scripts/signal_review.sh package-review`, after the
verdict, whether the review passed or not: whatever the build produced is packed, and what it did
not produce is named. The archive holds an offline index.html (relative links only, each checked
against the archive), the exact source revision and its comparison with 1085af3d, the original and
the correction's test manifests, the per-execution results, the raw result bundles and their JSON,
the failure evidence, the logs, every screenshot and note the tests attached, and SHA256SUMS.txt for
every file in it. Its own SHA-256 is written beside it (a zip cannot hold its own checksum).
Standard library only; Python 3.8+.
"""
import hashlib
import html
import json
import os
import re
import subprocess
import sys
import zipfile

TITLE = "Signal-Regression-Recovery"
BASELINE = "1085af3d7be62ef3fc463016446aa87c76b976f3"
SIGNAL_BUILD = "6ab7e9420cb984b7efbcbded"
REGRESSION_BUILD = "6ab7ee20d34a4b9811a96b06"
APP_ID = "6ab4d02869609bf0cdd94b08"
BUILD_URL = "https://codemagic.io/app/%s/build/%%s" % APP_ID
# The Signal scope's downloads, from build 3 (6ab7e942) on 1085af3d. Not re-captured here.
SIGNAL_DOWNLOADS = [
    ("Signal-Screens.zip", "2c5c0628e2e9ec7ef83d792d09c78b73503c6fdb1a3d43e86f311377b406ac76", 29832074,
     "screens of the Signal scope: XCTest journey captures and direct-launch fixtures"),
    ("Signal-walkthrough-compact.zip", "6d83ff82509edaccb3d1538a94ba0a4ccf2a5ca410702aea191399020186b934", 44191916,
     "Signal-walkthrough-compact-RE-ENCODED.mp4: a half-size AVFoundation re-encode, trimmed to the app"),
    ("Signal-walkthrough-original.zip", "e58528a95018fff9685958aa5aefe6244bbcf0b5e817df0136fd7203ae2180c6", 113998769,
     "Signal-walkthrough-original.mp4: the unedited simulator recording of the real journey"),
    ("Signal-Review.zip", "4924d60b8256a50dcd819ae2f9189fb60fb4669b7003c289609086234a358329", 228691354,
     "the Signal scope's full review page, results and logs"),
]
TEXT = (".txt", ".log", ".json", ".tsv", ".html", ".md", ".env", ".plist", ".sha256", ".csv")


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError:
        return ""


def kv(path):
    values = {}
    for line in read(path).splitlines():
        key, sep, value = line.partition("=")
        if sep:
            values.setdefault(key, value)
    return values


def safe(name):
    return "".join(c if c.isalnum() or c in "-_." else "_" for c in name).strip("._") or "file"


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


class Package:
    def __init__(self):
        self.files, self.texts, self.missing = {}, {}, []

    def add(self, name, source, required=True):
        if source and os.path.isfile(source):
            self.files[name] = source
            return name
        if required:
            self.missing.append(name)
        return None

    def add_tree(self, prefix, directory):
        count = 0
        for base, _, names in os.walk(directory):
            for name in sorted(names):
                path = os.path.join(base, name)
                relative = os.path.relpath(path, directory).replace(os.sep, "/")
                self.files[prefix + relative] = path
                count += 1
        return count

    def text(self, name, content):
        self.texts[name] = content
        return name


def walk_manifest(node, test=None):
    """xcresulttool export attachments: [{testIdentifier, attachments: [{exportedFileName, ...}]}]."""
    if isinstance(node, dict):
        test = node.get("testIdentifier", test)
        exported, readable = node.get("exportedFileName"), node.get("suggestedHumanReadableName")
        if exported and readable:
            yield str(exported), str(readable), float(node.get("timestamp") or 0), str(test or "unknown test"), \
                bool(node.get("isAssociatedWithFailure"))
        for value in node.values():
            yield from walk_manifest(value, test)
    elif isinstance(node, list):
        for value in node:
            yield from walk_manifest(value, test)


def main(argv):
    root, out, artifacts = argv[1:4]
    docs = os.path.join(root, "docs", "verification")
    pkg = Package()
    checkpoint = kv(os.path.join(out, "source-checkpoint.txt"))
    tests = kv(os.path.join(out, "ui-review-tests.txt"))
    verdict = read(os.path.join(out, "verdict.txt")) or "No verdict was produced in this run.\n"
    headline = next((l for l in verdict.splitlines() if l.startswith("AUTOMATED VERDICT")), "AUTOMATED VERDICT: not produced")
    head = checkpoint.get("git_head", "unknown (the source gate did not record it)")
    build_id = os.environ.get("CM_BUILD_ID", "")
    tools = kv(os.path.join(artifacts, "metadata", "tools.txt"))
    try:
        simulator = json.load(open(os.path.join(artifacts, "metadata", "simulator.json")))
    except (OSError, ValueError):
        simulator = {}

    # Source: the gate's record, the committed comparison with 1085af3d, and git's own view here.
    pkg.add("source/source-checkpoint.txt", os.path.join(out, "source-checkpoint.txt"))
    comparison = pkg.add("source/source-comparison-with-1085af3d.txt",
                         os.path.join(docs, "signal-regressions-recovery-source-comparison.txt"))
    try:
        stat = subprocess.run(["git", "diff", "--stat", BASELINE, "HEAD"], cwd=root, capture_output=True, text=True,
                              timeout=60)
        names = subprocess.run(["git", "diff", "--name-status", BASELINE, "HEAD"], cwd=root, capture_output=True,
                               text=True, timeout=60)
        git_view = ("git diff --name-status %s HEAD (exit %d):\n%s\ngit diff --stat (exit %d):\n%s%s"
                    % (BASELINE, names.returncode, names.stdout, stat.returncode, stat.stdout,
                       ("\n" + names.stderr + stat.stderr) if names.returncode or stat.returncode else ""))
    except (OSError, subprocess.SubprocessError) as error:
        git_view = "git diff against %s was unavailable on this machine: %r\n" % (BASELINE, error)
    pkg.text("source/git-diff-against-1085af3d-on-the-build-machine.txt", git_view)
    doc = pkg.add("source/signal-regression-correction.md", os.path.join(root, "docs", "reports",
                                                                          "signal-regression-correction.md"))

    # Manifests.
    original = pkg.add("manifests/original-regressions-manifest-6ab7ee20.txt",
                       os.path.join(docs, "signal-regressions-original-manifest.txt"))
    recovery = pkg.add("manifests/recovery-manifest.tsv", os.path.join(docs, "signal-regressions-recovery-manifest.tsv"))
    rows = []
    for line in read(os.path.join(docs, "signal-regressions-recovery-manifest.tsv")).splitlines():
        if line.strip() and not line.startswith("#"):
            order, device, run, bundle, test, kind = line.split("\t")
            rows.append({"order": order, "device": device, "run": run, "bundle": bundle, "test": test.replace("/", "."),
                         "kind": kind})
    before = {}
    for line in read(os.path.join(docs, "signal-regressions-original-manifest.txt")).splitlines():
        if line.strip() and not line.startswith("#"):
            lane, test = line.split()
            before[test] = lane
    lane_name = {"main": "selected iPhone 17 Pro Max", "b": "device B (its clone)"}
    compare = []
    for row in rows:
        was = before.get(row["test"])
        if row["kind"] == "repeat":
            change = "added: a planned repeat of a required test (not a unique test, not a retry)"
        elif was is None:
            change = "NEW: not in the original manifest"
        elif was != row["device"]:
            change = "moved from the %s to the %s" % (lane_name.get(was, was), lane_name.get(row["device"], row["device"]))
        else:
            change = "same device; now in run %s" % row["run"]
        compare.append((row, was, change))
    dropped = sorted(set(before) - {r["test"] for r in rows})
    comparison_text = "\n".join("%s\t%s\t%s\t%s\t%s" % (row["order"], row["test"], was or "-", row["device"], change)
                                for row, was, change in compare)
    comparison_text = ("order\ttest\toriginal lane\tnew lane\tchange\n" + comparison_text + "\n" +
                       ("DROPPED from the original manifest: " + ", ".join(dropped) if dropped else
                        "Every test of the original manifest is in the new one.") + "\n")
    pkg.text("manifests/manifest-comparison.tsv", comparison_text)

    # Results: the verdict, the per-execution table, the run exits, the summary and every JSON.
    for name in ("verdict.txt", "ui-review-tests.txt", "ui-review-counts.txt", "executions.tsv", "runs.txt", "required.txt",
                 "destination.txt", "captures.tsv"):
        pkg.add("results/" + name, os.path.join(out, name), required=name in ("verdict.txt", "executions.tsv", "runs.txt"))
    pkg.add("results/summary.txt", os.path.join(artifacts, "summary.txt"))
    for name in sorted(os.listdir(out)) if os.path.isdir(out) else []:
        if name.endswith(("-summary.json", "-tests.json")):
            pkg.add("results/json/" + name, os.path.join(out, name))
    for folder, prefix in (("metadata", "results/metadata/"), ("logs", "logs/")):
        directory = os.path.join(artifacts, folder)
        for name in sorted(os.listdir(directory)) if os.path.isdir(directory) else []:
            if name.endswith((".txt", ".log", ".json", ".env")) and os.path.isfile(os.path.join(directory, name)):
                pkg.add(prefix + name, os.path.join(directory, name))
    app_dir = os.path.join(artifacts, "app")
    app_files = sorted(os.listdir(app_dir)) if os.path.isdir(app_dir) else []
    for name in app_files:
        if name.endswith(".sha256"):
            pkg.add("results/app/" + name, os.path.join(app_dir, name))
    raw = []
    for name in sorted(os.listdir(out)) if os.path.isdir(out) else []:
        if name.endswith(".xcresult") and os.path.isdir(os.path.join(out, name)):
            raw.append((name, pkg.add_tree("raw/%s/" % name, os.path.join(out, name))))

    # Attachments: every screenshot and note, per run and test.
    shots, notes, failures_art = {}, [], {}
    folders = sorted(n for n in os.listdir(out) if n.startswith("attachments-")) if os.path.isdir(out) else []
    for folder in folders:
        bundle = folder[len("attachments-"):]
        directory = os.path.join(out, folder)
        try:
            items = list(walk_manifest(json.load(open(os.path.join(directory, "manifest.json")))))
        except (OSError, ValueError):
            items = [(n, n, 0.0, "unknown test", False) for n in sorted(os.listdir(directory))]
        used = set()
        for exported, readable, stamp, test, with_failure in sorted(items, key=lambda i: i[2]):
            source = os.path.join(directory, exported)
            extension = os.path.splitext(exported)[1].lower()
            if extension not in (".png", ".jpg", ".jpeg", ".txt", ".json", ".heic") or not os.path.isfile(source):
                continue
            test_name = test.split("/")[-1].replace("()", "")
            test_class = test.split("/")[0] if "/" in test else ""
            stem = safe(readable.split("_0_")[0])
            if stem.lower().endswith(extension):
                stem = stem[:-len(extension)]
            candidate, n = stem + extension, 1
            while candidate in used:
                n += 1
                candidate = "%s-%d%s" % (stem, n, extension)
            used.add(candidate)
            name = pkg.add("screenshots/%s/%s/%s" % (safe(bundle), safe(test_class + "." + test_name), candidate), source)
            key = (bundle, "%s.%s" % (test_class, test_name))
            if extension in (".png", ".jpg", ".jpeg"):
                shots.setdefault(key, []).append((name, readable.split("_0_")[0], with_failure))
            elif extension == ".txt":
                notes.append((key, readable.split("_0_")[0], read(source).strip(), name))
            if with_failure:
                failures_art.setdefault(key, []).append(name)

    # The executions, from the parser's table.
    executions = []
    table = read(os.path.join(out, "executions.tsv")).splitlines()
    if table:
        header = table[0].split("\t")
        for line in table[1:]:
            cells = line.split("\t")
            executions.append(dict(zip(header, cells + [""] * (len(header) - len(cells)))))
    json_failures = {}
    for name in sorted(os.listdir(out)) if os.path.isdir(out) else []:
        if name.endswith("-summary.json"):
            try:
                summary = json.load(open(os.path.join(out, name)))
            except (OSError, ValueError):
                continue
            for failure in summary.get("testFailures", []) or []:
                ident = str(failure.get("testIdentifierString", "")).replace("()", "").replace("/", ".")
                json_failures.setdefault((name[:-len("-summary.json")], ident), []).append(str(failure.get("failureText", "")))

    def esc(text):
        return html.escape(str(text))

    def gallery(items, caption_prefix=""):
        if not items:
            return '<p class="missing">No screenshots were attached.</p>'
        return '<div class="row">%s</div>' % "".join(
            '<figure><a href="%s"><img src="%s" alt="%s" loading="lazy"></a><figcaption>%s%s%s</figcaption></figure>'
            % (esc(n), esc(n), esc(label), esc(caption_prefix), esc(label), " (attached with a failure)" if fail else "")
            for n, label, fail in items)

    def notes_for(predicate):
        found = [(key, label, text, name) for key, label, text, name in notes if predicate(key, label, text)]
        if not found:
            return '<p class="missing">No notes were attached.</p>'
        return "<pre>%s</pre>" % esc("\n\n".join("%s (%s): %s" % (key[1], key[0], text) for key, label, text, name in found))

    def outcome_of(test, bundle=None):
        found = [e for e in executions if e.get("test") == test and (bundle is None or e.get("bundle") == bundle)]
        return "; ".join("%s %s: %s%s" % (e.get("order"), e.get("run"), e.get("outcome"),
                                          (" (%s s)" % e["seconds"]) if e.get("seconds") else "") for e in found) \
            or "not in this build's results"

    paste_test = "GuestListReviewTests.testOpenerLimitBoundariesAndPreservedPaste"
    names_test = "GuestListReviewTests.testBlankInternationalAndLongNames"
    wristband_walk = "WristbandReviewTests.testWalkthroughRouteChoicesBackReentryEndpoint"
    birthday_walk = "BirthdayReviewTests.testWalkthroughEntryCorrectionContinueBack"

    def shots_of(test, bundles=None, names=None):
        items = []
        for (bundle, key_test), found in sorted(shots.items()):
            if key_test == test and (bundles is None or bundle in bundles):
                items += [(n, "%s, %s" % (label, bundle), fail) for n, label, fail in found
                          if names is None or any(label.startswith(x) for x in names)]
        return items

    required = [e for e in executions if e.get("kind") == "required"]
    rows_html = "".join(
        "<tr class=\"%s\"><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>"
        % ("ok" if e.get("outcome") == "passed" else ("info" if e.get("kind") == "repeat" and e.get("outcome", "").startswith("not run") else "bad"),
           esc(e.get("order")), esc(e.get("device")), esc(e.get("run")), esc(e.get("test")), esc(e.get("kind")),
           esc(e.get("outcome")), esc(e.get("seconds")), esc(e.get("failure")))
        for e in executions) or '<tr><td colspan="8" class="missing">No per-execution results were produced.</td></tr>'
    compare_html = "".join("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>"
                           % (esc(row["order"]), esc(row["test"]), esc(lane_name.get(was, was or "-")), esc(change))
                           for row, was, change in compare)
    bad = [e for e in executions if e.get("outcome") != "passed"
           and not (e.get("kind") == "repeat" and e.get("outcome", "").startswith("not run (time"))]
    failure_html = ""
    for e in bad:
        key = (e.get("bundle"), e.get("test"))
        texts = [t for t in (e.get("failure") or "").split(" | ") if t] or json_failures.get(key, [])
        failure_html += "<h3>%s %s (%s, %s): %s</h3>%s%s" % (
            esc(e.get("order")), esc(e.get("test")), esc(e.get("run")), esc(e.get("device")), esc(e.get("outcome")),
            "<pre>%s</pre>" % esc("\n".join(texts)) if texts else '<p class="note">No failure message was recorded.</p>',
            gallery([(n, label, fail) for n, label, fail in shots.get(key, [])]))
    if not failure_html:
        if required and all(e.get("outcome") == "passed" for e in required):
            failure_html = '<p class="okline">Every required execution passed; no failure evidence to show.</p>'
        else:
            failure_html = ('<p class="missing">No per-execution results were produced (the UI review stopped before its '
                            'results were parsed), so no failure evidence could be matched to a test; see the verdict and '
                            'the logs below.</p>')
    downloads_html = "".join(
        "<tr><td><code>%s</code></td><td><code>%s</code></td><td>%s</td><td>%s</td></tr>"
        % (esc(n), esc(d), "{:,}".format(size), esc(what)) for n, d, size, what in SIGNAL_DOWNLOADS)
    all_shots = "".join("<h3>%s — %s</h3>%s" % (esc(bundle), esc(test), gallery(found))
                        for (bundle, test), found in sorted(shots.items()))
    link_list = " | ".join('<a href="%s">%s</a>' % (esc(n), esc(n)) for n in sorted(list(pkg.files) + list(pkg.texts))
                           if n.startswith(("results/", "logs/", "source/", "manifests/")))
    raw_html = "".join("<li><code>raw/%s/</code>: %d files (open the folder with Xcode, or use xcresulttool)</li>" % (esc(n), c)
                       for n, c in raw) or '<li class="missing">No result bundles were produced.</li>'
    counts = ("<ul><li><b>Unique test cases executed:</b> %s (the manifest has 27 required unique cases)</li>"
              "<li><b>Executions</b> (unique cases plus the planned repeat; each on its recorded device): %s — passed %s, "
              "failed %s, skipped %s, started without a recorded outcome (a time bound, a runner crash or restart) %s</li>"
              "<li><b>First attempts:</b> %s</li><li><b>Retries:</b> %s; tests executed more than once in one run: %s</li>"
              "<li><b>Planned repeat</b> (not a unique test, not a retry): %s</li>"
              "<li><b>Infrastructure reruns</b> (simulator not found, no test ran): %s</li></ul>"
              % tuple(esc(tests.get(k, "not produced")) for k in (
                  "unique_test_cases", "executions", "passed", "failed", "skipped", "interrupted", "first_attempt_required",
                  "retries", "retried", "repeats", "infrastructure_reruns")))
    build_label = ('<a href="%s">Codemagic build %s</a>' % (esc(BUILD_URL % build_id), esc(build_id))) if build_id \
        else "a run outside Codemagic"

    page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Signal regression correction</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;margin:24px;background:#111;color:#eee}
h1{font-size:22px}h2{font-size:18px;margin-top:34px;border-top:1px solid #333;padding-top:16px}h3{font-size:15px;margin-top:22px}
.row{display:flex;flex-wrap:wrap;gap:16px;margin-bottom:12px}figure{margin:0}figcaption{color:#aaa;font-size:12px;max-width:260px}
img{width:240px;max-width:100%%;border:1px solid #333;border-radius:8px;background:#000}
table{border-collapse:collapse;max-width:1200px}td,th{border:1px solid #333;padding:5px 7px;vertical-align:top;font-size:12.5px;text-align:left}
tr.ok td:nth-child(6){color:#8f8}tr.bad td:nth-child(6){color:#f88;font-weight:bold}tr.info td:nth-child(6){color:#fc6}
pre{white-space:pre-wrap;background:#1b1b1b;padding:12px;border-radius:8px;font-size:12px}.missing{color:#f99}.okline{color:#8f8}
.note{color:#ccc;max-width:900px}code{font-size:12.5px}</style></head><body>
<h1>Proximeet Signal: regression correction, iOS Simulator</h1>
<p><b>%(headline)s</b></p>
<p class="note">%(build)s, scope “regressions”. Source <code>%(head)s</code> (pinned: %(pin)s). %(host)s</p>
<h2>Two revisions, stated separately</h2>
<ul class="note">
<li>The <b>signal</b> scope ran at <code>%(baseline)s</code> in Codemagic build <a href="%(signal_url)s">%(signal_build)s</a>
(16 executions, 14 unique tests, PASS). It is <b>not</b> re-run here, and none of its screens or videos are relabelled as new
captures. Its downloads are listed at the end of this page.</li>
<li>The <b>regressions</b> scope ran at <code>%(head)s</code> in this build. The earlier regression build on
<code>%(baseline)s</code>, <a href="%(regression_url)s">%(regression_build)s</a>, FAILED: the Guest List paste failed twice, the
Wristband walkthrough never finished, and the Birthday walkthrough passed only on a retry.</li>
<li>What differs between the two revisions: <a href="%(comparison)s">source comparison with 1085af3d</a> (committed with the
correction; the app's sources, assets, fonts, project configuration and domain code are compared file by file) and
<a href="source/git-diff-against-1085af3d-on-the-build-machine.txt">git's own diff on the build machine</a>. For unchanged
product files the equivalence is by source; it does not mean the signal scope's tests ran on this commit.</li></ul>
<h2>Counts: unique cases, executions, first attempts, retries</h2>%(counts)s
<h2>Every execution, by the manifest</h2>
<p class="note">Order, device and run come from <a href="%(recovery)s">the correction's manifest</a>; the outcome of each row is
its only execution in that run (automatic retries are off). A required row passes only if it executed once and passed.</p>
<table><tr><th>#</th><th>Device</th><th>Run</th><th>Test</th><th>Kind</th><th>Outcome</th><th>s</th><th>Failure</th></tr>%(rows)s</table>
<h2>The original manifest (build 6ab7ee20) and this one</h2>
<p class="note"><a href="%(original)s">Original manifest</a> · <a href="manifests/manifest-comparison.tsv">comparison</a></p>
<table><tr><th>#</th><th>Test</th><th>Original lane</th><th>Change</th></tr>%(compare)s</table>
<h2>Guest List paste (the failure of build 6ab7ee20)</h2>
<p class="note">testOpenerLimitBoundariesAndPreservedPaste: <b>%(paste)s</b>. testBlankInternationalAndLongNames (five pastes
through the same helper): <b>%(names)s</b>. Each paste attaches a note with every step and its time.</p>
%(paste_notes)s%(paste_shots)s
<h2>Wristband walkthrough (never finished in build 6ab7ee20)</h2>
<p class="note">testWalkthroughRouteChoicesBackReentryEndpoint: <b>%(wristband)s</b>. Every screenshot it attached:</p>%(wristband_shots)s
<h2>Birthday short Month drag (passed only on a retry in build 6ab7ee20)</h2>
<p class="note">testWalkthroughEntryCorrectionContinueBack: <b>%(birthday)s</b>. The lane, the rest checks before and after the
drag, the time the gesture took, and the pixels around the unset placeholders:</p>
%(birthday_notes)s%(birthday_shots)s
<h2>Failure evidence</h2>%(failures)s
<h2>Every screenshot, by run and test</h2>%(all_shots)s
<h2>Notes attached by the tests</h2><pre>%(all_notes)s</pre>
<h2>Raw results</h2><ul class="note">%(raw)s<li>JSON from xcresulttool (summary and the full test tree) is under
<code>results/json/</code>; <a href="SHA256SUMS.txt">SHA256SUMS.txt</a> covers every file in this archive.</li></ul>
<h2>The signal scope's downloads (build 6ab7e942 on 1085af3d, not re-run)</h2>
<p class="note">On the build page <a href="%(signal_url)s">%(signal_url)s</a> (sign in to Codemagic), under Artifacts:</p>
<table><tr><th>Artifact</th><th>SHA-256</th><th>Bytes</th><th>Contents</th></tr>%(downloads)s</table>
<h2>Still open (not reviewed by automation)</h2>
<ul class="note"><li>Visual approval of Signal: the lead has not yet inspected its captures.</li><li>VoiceOver.</li>
<li>The system Reduce Motion setting (only the app's preview flag is tested).</li><li>Composing keyboards (Japanese, Chinese,
Korean).</li><li>Real-device checks, including motion smoothness.</li></ul>
<h2>Result, logs and files</h2><pre>%(verdict)s</pre>
<p>%(links)s</p>
<p class="missing">%(missing)s</p>
</body></html>""" % {
        "headline": esc(headline), "build": build_label, "head": esc(head), "pin": esc(checkpoint.get("commit_pin", "?")),
        "host": esc("Host %s; %s %s; %s, %s." % (tools.get("cpu", "?"), tools.get("xcode", "?"), tools.get("xcode_build", ""),
                                                simulator.get("device_name", "?"), simulator.get("runtime_name", "?"))),
        "baseline": BASELINE, "signal_build": SIGNAL_BUILD, "signal_url": esc(BUILD_URL % SIGNAL_BUILD),
        "regression_build": REGRESSION_BUILD, "regression_url": esc(BUILD_URL % REGRESSION_BUILD),
        "comparison": esc(comparison or "source/git-diff-against-1085af3d-on-the-build-machine.txt"),
        "counts": counts, "recovery": esc(recovery or "SHA256SUMS.txt"), "rows": rows_html,
        "original": esc(original or "manifests/manifest-comparison.tsv"), "compare": compare_html,
        "paste": esc(outcome_of(paste_test)), "names": esc(outcome_of(names_test)),
        "paste_notes": notes_for(lambda key, label, text: key[1] in (paste_test, names_test) and
                                 (text.startswith("Paste into") or "Allow Paste" in text)),
        "paste_shots": gallery(shots_of(paste_test) + shots_of(names_test, names=("paste-",))),
        "wristband": esc(outcome_of(wristband_walk)), "wristband_shots": gallery(shots_of(wristband_walk)),
        "birthday": esc(outcome_of(birthday_walk)),
        "birthday_notes": notes_for(lambda key, label, text: key[1] == birthday_walk and
                                    ("Month" in text or "Before the Month drag" in text or "wheels were" in text)),
        "birthday_shots": gallery(shots_of(birthday_walk)),
        "failures": failure_html, "all_shots": all_shots or '<p class="missing">No screenshots were produced.</p>',
        "all_notes": esc("\n\n".join("%s (%s): %s" % (key[1], key[0], text) for key, label, text, name in notes) or "none"),
        "raw": raw_html, "downloads": downloads_html, "verdict": esc(verdict), "links": link_list,
        "missing": esc(("Not produced in this run: " + ", ".join(pkg.missing)) if pkg.missing else ""),
    }
    pkg.text("index.html", page)

    # Every relative link must name a file in the archive.
    targets = set(re.findall(r'(?:src|href)="([^"#:]+)"', page))
    present = set(pkg.files) | set(pkg.texts) | {"SHA256SUMS.txt"}
    broken = sorted(t for t in (html.unescape(t) for t in targets) if t not in present)

    # SHA256SUMS.txt, then the archive and its own checksum.
    sums = {name: sha256_file(path) for name, path in pkg.files.items()}
    sums.update({name: hashlib.sha256(content.encode("utf-8")).hexdigest() for name, content in pkg.texts.items()})
    pkg.text("SHA256SUMS.txt", "".join("%s  %s\n" % (sums[n], n) for n in sorted(sums)))
    os.makedirs(artifacts, exist_ok=True)
    out_zip = os.path.join(artifacts, TITLE + ".zip")
    with zipfile.ZipFile(out_zip, "w", allowZip64=True) as bundle:
        for name, content in sorted(pkg.texts.items()):
            bundle.writestr(TITLE + "/" + name, content, compress_type=zipfile.ZIP_DEFLATED)
        for name, path in sorted(pkg.files.items()):
            kind = zipfile.ZIP_DEFLATED if name.lower().endswith(TEXT) else zipfile.ZIP_STORED
            bundle.write(path, TITLE + "/" + name, compress_type=kind)
    digest = sha256_file(out_zip)
    with open(out_zip + ".sha256", "w") as handle:
        handle.write("%s  %s\n" % (digest, os.path.basename(out_zip)))
    with open(os.path.join(out, "package-links.txt"), "w") as handle:
        handle.write("links=%d\nbroken=%s\nfiles=%d\nsha256=%s\n" % (len(targets), ",".join(broken) or "none",
                                                                     len(pkg.files) + len(pkg.texts), digest))
    print("%s.zip: %d files (%d result-bundle files), %d relative links checked, %d broken%s; sha256 %s" % (
        TITLE, len(pkg.files) + len(pkg.texts), sum(c for _, c in raw), len(targets), len(broken),
        ("; missing: " + ", ".join(pkg.missing)) if pkg.missing else "", digest))
    if broken:
        print("BROKEN relative links in index.html: " + ", ".join(broken))
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

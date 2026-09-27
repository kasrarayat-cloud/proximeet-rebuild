#!/usr/bin/env python3
"""Proximeet Places recovery: reconcile the recovery builds row by row.

    python3 scripts/places_recovery_reconcile.py [--manifest PATH] [--coverage PATH] [--tsv OUT]
        [--assume-product-equivalent SHA ...] BUILD [BUILD ...]

The recovery after the Places correction ran out of builds before it could run every row in one
build per scope. Build 2 (Codemagic 6ab8c585873de42fcd4f1a8a, scope correction, on 808950f) passed
C10-C15 on the smaller iPhone; on the iPhone 17 Pro Max every run exited 65 before any test started
(the test runner failed to initialize for UI testing). Build 3 (scope gate_finish) runs C1-C9 and
extras, build 4 (scope sweep_finish) the other scheduled rows; B2-B9 and the optional repeat B14 run
in no recovery build. So the reconciliation is by row, not by build, and it gives two verdicts.

Each BUILD is one build's results, in any number and order: its downloaded review archive (for
example Places-Correction-Review.zip, Places-Gate-Review.zip, Places-Finish-Review.zip), the folder
that archive unpacks to, or a folder holding the build's results (build/artifacts itself works). From
each it reads executions.tsv, source-checkpoint.txt (git_head and scope), metadata/source.txt (the
Codemagic build ID; its git_head when the checkpoint is missing), verdict.txt, metadata/simulator.json
(the selected simulator's model and runtime) and smaller.txt (the smaller iPhone). The same build given
twice (its archive and its folder) counts once.

The targets are the correction scope's 15 required rows (C1-C15) and the 56 earlier required
executions (places 13, signal 16, regressions 27) of docs/verification/places-review-manifest.tsv
(--manifest), and the optional repeat B14, which counts toward no verdict.
docs/verification/places-recovery-coverage.tsv (--coverage) names, for each, the build, scope and run
expected to execute it, or "pending"; it is checked against the manifest first.

A target is covered by a PASSED execution, of kind required or extra (for the repeat B14: of kind
repeat, a second execution of its own), of the same test on the same device class, in the same run
type, in a given build whose git_head is product-equivalent to 808950f8102d1c0e0f6c3422fc0aed3a0df555fe:

    git diff --name-only <git_head> 808950f8102d1c0e0f6c3422fc0aed3a0df555fe -- \\
        Proximeet ProximeetDomain ProximeetUITests Proximeet.xcodeproj assets

must print nothing (run in this repository; every head and its result are printed). Build 1
(Codemagic 6ab8adb4, on 907d7401) never counts. Device classes: main and b are one class, the iPhone
17 Pro Max model and runtime (device B is the selected simulator's clone); small is the iPhone 17e. A
build whose recorded selected simulator is not an iPhone 17 Pro Max counts for no main-class row, one
whose recorded smaller iPhone is not an iPhone 17e for no small-class row, a build whose runtime is not
recorded (simulator.json with its runtime name and build) for no row of either class, and the counted
builds must share one runtime. Run types: a run named "journey" is recorded with full holds; every other run uses
short holds. The stated identity exceptions, accepted and printed where they apply: P1 runs with short
holds, unrecorded (the places scope's P1 was the recorded journey); the M rows run on device B instead
of main (the same model and runtime).

An executed execution of a target's test on its device class that did not pass (failed, skipped,
interrupted, executed twice) in a product-equivalent build is a failure, whatever its kind: retries
are off, and an optional run that runs must pass. "not run" outcomes are neither.

Two verdicts, printed separately (build-level verdicts are informational only; build 2 failed on
infrastructure, but its passed rows count):
  TARGETED CORRECTION  PASS when C1-C15 all passed and none failed; otherwise FAIL, listing the
                       failed and the missing rows.
  FULL REGRESSION      PASS when all 56 earlier required executions are covered; FAIL when any of
                       them failed; otherwise INCOMPLETE, listing every uncovered row and why
                       (pending: not scheduled; or what the builds show).
A coverage file that disagrees with the manifest, an unreadable build or device classes that differ
between counted builds make both verdicts FAIL.

--assume-product-equivalent SHA (repeatable) is a TEST MODE for stubbed results whose git_head is not
a real commit (for example 0000000000000000000000000000000000000000): that head is treated as
product-equivalent without running git, which is printed beside it and appended to both verdicts. Never
use it for real builds. --tsv OUT also writes the joined table.

Exit 0: both verdicts PASS. Exit 3: TARGETED CORRECTION PASS and FULL REGRESSION INCOMPLETE. Exit 1:
any FAIL. Exit 2: a usage error. Standard library only; Python 3.8+.
"""
import json
import os
import re
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "docs/verification/places-review-manifest.tsv")
COVERAGE = os.path.join(ROOT, "docs/verification/places-recovery-coverage.tsv")
REFERENCE = "808950f8102d1c0e0f6c3422fc0aed3a0df555fe"
PRODUCT_PATHS = ("Proximeet", "ProximeetDomain", "ProximeetUITests", "Proximeet.xcodeproj", "assets")
NEVER_COUNTS = {"907d7401ec8b97a10138c2764094a9c564d0e4ce": "build 1 (Codemagic 6ab8adb4, the first correction build)"}
MAIN_MODEL, SMALL_MODEL = "iPhone 17 Pro Max", "iPhone 17e"
CLASS = {"main": "main", "b": "main", "small": "small"}
EARLIER = ("places", "signal", "regressions")
# Required targets per scope, so a row dropped from both the manifest and the coverage file cannot pass unseen.
PLAN = {"correction": 15, "places": 13, "signal": 16, "regressions": 27}
# The recovery's build numbers, by the scope that executes a row.
BUILD = {"correction": "2", "gate_finish": "3", "sweep_finish": "4"}
RUN_TYPE_EXCEPTIONS = {"places:P1": "P1 runs with short holds, unrecorded (the places scope's P1 was the recorded "
                                    "journey with full holds; its assertions are the same)"}
DEVICE_B_EXCEPTION = ("rows run on device B instead of the selected simulator (the M rows, in sweep_finish): device B "
                      "is its clone, the same iPhone 17 Pro Max model and runtime")
WANTED = ("executions.tsv", "source-checkpoint.txt", "verdict.txt", "ui-review-tests.txt", "source.txt",
          "simulator.json", "smaller.txt")
COVERAGE_COLUMNS = ("target", "requirement", "test", "class", "build", "scope", "run", "row", "kind", "note")


def rows_of(text):
    """The non-comment lines of a tab-separated file, split."""
    return [line.split("\t") for line in text.splitlines() if line.strip() and not line.startswith("#")]


def kv(text):
    values = {}
    for line in text.splitlines():
        key, sep, value = line.partition("=")
        if sep:
            values.setdefault(key.strip(), value.strip())
    return values


def natural(order):
    """A row ID's sort key: P2 before P10."""
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", order)]


def run_type(run):
    return "recorded journey, full holds" if run == "journey" else "short holds"


def dotted(test):
    return test.replace("/", ".")


def load_build(path):
    """The build's result files, by base name: {name: text}. Prefers the shallowest match; source.txt and
    simulator.json only from a metadata folder."""
    found = {}

    def take(name, depth, reader):
        base = name.rsplit("/", 1)[-1]
        if base not in WANTED or (base in ("source.txt", "simulator.json") and "metadata/" not in name):
            return
        if base not in found or depth < found[base][0]:
            found[base] = (depth, reader)

    if os.path.isfile(path) and zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as bundle:
            for name in bundle.namelist():
                if not name.endswith("/"):
                    take(name, name.count("/"), (lambda n: lambda: bundle.read(n).decode("utf-8", "replace"))(name))
            return {base: reader() for base, (depth, reader) in found.items()}
    if not os.path.isdir(path):
        raise OSError("not a folder or a zip archive: %s" % path)
    for directory, subdirectories, files in os.walk(path):
        subdirectories.sort()
        subdirectories[:] = [d for d in subdirectories if not d.endswith(".xcresult")]
        relative = os.path.relpath(directory, path)
        depth = 0 if relative == "." else relative.count(os.sep) + 1
        if depth > 4:
            subdirectories[:] = []
            continue
        for name in files:
            full = os.path.join(directory, name)
            take(os.path.relpath(full, path).replace(os.sep, "/"), depth,
                 (lambda f: lambda: open(f, encoding="utf-8", errors="replace").read())(full))
    return {base: reader() for base, (depth, reader) in found.items()}


def product_check(head, assumed):
    """(counts, command, result): whether the head is product-equivalent to REFERENCE, and how that was found."""
    command = "git diff --name-only %s %s -- %s" % (head or "<no git_head>", REFERENCE, " ".join(PRODUCT_PATHS))
    if head in assumed:
        return True, command, "not run: ASSUMED product-equivalent (--assume-product-equivalent; TEST MODE, not a real result)"
    if not re.fullmatch(r"[0-9a-f]{40}", head or ""):
        return False, command, "not run: the build names no full 40-hex git_head -> NOT counted"
    result = subprocess.run(["git", "-C", ROOT, "diff", "--name-only", head, REFERENCE, "--"] + list(PRODUCT_PATHS),
                            capture_output=True, text=True)
    if result.returncode != 0:
        reason = (result.stderr.strip().splitlines() or ["no message"])[0]
        return False, command, "git exit %d (%s) -> NOT counted: product equivalence not established" % (
            result.returncode, reason)
    files = [line for line in result.stdout.splitlines() if line.strip()]
    if files:
        return False, command, "%d product or test file(s) differ -> NOT product-equivalent, NOT counted: %s" % (
            len(files), ", ".join(files[:8]) + (" ..." if len(files) > 8 else ""))
    if head in NEVER_COUNTS:
        return False, command, "(no output) but this is %s, which never counts -> NOT counted" % NEVER_COUNTS[head]
    return True, command, "(no output) -> PRODUCT-EQUIVALENT: its executions count"


def classify(outcome):
    """passed | not run | identity (passed, but on the wrong or an unrecorded device) | failure."""
    if outcome == "passed":
        return "passed"
    if not outcome or outcome.startswith(("not run", "missing")):
        return "not run"
    if "executions in one run" in outcome:
        # A test executed more than once in one run (retries are off), whatever the outcomes.
        return "failure"
    if outcome.startswith("passed "):
        return "identity"
    return "failure"


def main(argv):
    args, paths, assumed = argv[1:], [], set()
    manifest_path, coverage_path, tsv_path = MANIFEST, COVERAGE, ""
    while args:
        arg = args.pop(0)
        if arg in ("--manifest", "--coverage", "--tsv", "--assume-product-equivalent") and args:
            value = args.pop(0)
            if arg == "--manifest":
                manifest_path = value
            elif arg == "--coverage":
                coverage_path = value
            elif arg == "--tsv":
                tsv_path = value
            else:
                value = value.strip().lower()
                if not re.fullmatch(r"[0-9a-f]{40}", value):
                    sys.stderr.write("--assume-product-equivalent needs a 40-hex git_head\n")
                    return 2
                assumed.add(value)
        elif arg in ("-h", "--help"):
            sys.stdout.write(__doc__)
            return 0
        elif arg.startswith("--"):
            sys.stderr.write("unknown option %s\n\n%s" % (arg, __doc__))
            return 2
        else:
            paths.append(arg)
    if not paths:
        sys.stderr.write(__doc__)
        return 2
    try:
        manifest_text = open(manifest_path, encoding="utf-8").read()
        coverage_text = open(coverage_path, encoding="utf-8").read()
    except OSError as error:
        sys.stderr.write("%s\n" % error)
        return 2

    problems, notes = [], []

    # 1. The manifest's targets, and the coverage file against the manifest.
    manifest = {}
    for cells in rows_of(manifest_text):
        if len(cells) != 8:
            problems.append("manifest line with %d columns, not 8: %s" % (len(cells), "\t".join(cells)))
            continue
        scope, order, device, run, bundle, seconds, test, kind = cells
        manifest[(scope, order)] = {"scope": scope, "order": order, "device": device, "run": run, "test": test,
                                    "kind": kind}
    targets = {}
    for (scope, order), row in manifest.items():
        if (scope == "correction" and row["kind"] == "required") or scope in EARLIER:
            targets["%s:%s" % (scope, order)] = row
    for scope, planned in PLAN.items():
        found = sum(1 for row in targets.values() if row["scope"] == scope and row["kind"] == "required")
        if found != planned:
            problems.append("the manifest has %d required %s rows; the recovery reconciles %d" % (found, scope, planned))

    coverage = {}
    for cells in rows_of(coverage_text):
        if cells[0] == "target":
            continue
        if len(cells) != len(COVERAGE_COLUMNS):
            problems.append("coverage line with %d columns, not %d: %s" % (len(cells), len(COVERAGE_COLUMNS),
                                                                          "\t".join(cells)))
            continue
        entry = dict(zip(COVERAGE_COLUMNS, cells))
        target = entry["target"]
        if target in coverage:
            problems.append("coverage lists %s twice" % target)
        coverage[target] = entry
        row = targets.get(target)
        if row is None:
            problems.append("coverage target %s is not a required correction row or an earlier places, signal or "
                            "regressions row of the manifest" % target)
            continue
        requirement = "required" if row["kind"] == "required" else "optional (%s)" % row["kind"]
        for field, mine, theirs in (("requirement", entry["requirement"], requirement), ("test", entry["test"], row["test"]),
                                    ("class", entry["class"], CLASS.get(row["device"], "?"))):
            if mine != theirs:
                problems.append("coverage %s: %s %r, but the manifest says %r" % (target, field, mine, theirs))
        if entry["scope"] == "pending":
            if any(entry[f] != "-" for f in ("build", "run", "row", "kind")):
                problems.append("coverage %s is pending but names a build, run, row or kind" % target)
            continue
        executor = manifest.get((entry["scope"], entry["row"]))
        if entry["scope"] not in BUILD or executor is None:
            problems.append("coverage %s names %s %s, which is not a row of the correction, gate_finish or sweep_finish "
                            "scope" % (target, entry["scope"], entry["row"]))
            continue
        if entry["build"] != BUILD[entry["scope"]]:
            problems.append("coverage %s says build %s; %s is build %s" % (target, entry["build"], entry["scope"],
                                                                          BUILD[entry["scope"]]))
        for field, mine, theirs in (("run", entry["run"], executor["run"]), ("kind", entry["kind"], executor["kind"]),
                                    ("test", entry["test"], executor["test"]),
                                    ("class", entry["class"], CLASS.get(executor["device"], "?"))):
            if mine != theirs:
                problems.append("coverage %s: the executing row %s %s has %s %r, not %r" % (
                    target, entry["scope"], entry["row"], field, theirs, mine))
        if executor["kind"] not in ("required", "extra"):
            problems.append("coverage %s: the executing row %s %s is of kind %s, which never counts" % (
                target, entry["scope"], entry["row"], executor["kind"]))
        if run_type(executor["run"]) != run_type(row["run"]) and target not in RUN_TYPE_EXCEPTIONS:
            problems.append("coverage %s: the executing row %s %s runs with %s, not %s: not the same check" % (
                target, entry["scope"], entry["row"], run_type(executor["run"]), run_type(row["run"])))
    for target in sorted(set(targets) - set(coverage), key=lambda t: (t.split(":")[0], natural(t.split(":")[1]))):
        problems.append("manifest target %s is missing from the coverage file" % target)
    scheduled = {(e["scope"], e["row"]) for e in coverage.values() if e["scope"] != "pending"}
    for (scope, order), row in sorted(manifest.items()):
        if scope in ("gate_finish", "sweep_finish") and (scope, order) not in scheduled:
            problems.append("manifest row %s %s is not the expected executor of any coverage target" % (scope, order))

    # 2. The builds.
    builds, seen = [], {}
    for path in paths:
        try:
            files = load_build(path)
        except (OSError, zipfile.BadZipFile) as error:
            problems.append("%s: unreadable (%s)" % (path, error))
            continue
        checkpoint, tests = kv(files.get("source-checkpoint.txt", "")), kv(files.get("ui-review-tests.txt", ""))
        source = kv(files.get("source.txt", ""))
        verdict = files.get("verdict.txt", "")
        identity = (files.get("source-checkpoint.txt", ""), files.get("executions.tsv", ""))
        if identity in seen and any(identity):
            notes.append("%s is the same build as %s (identical checkpoint and executions); counted once" % (
                path, seen[identity]))
            continue
        seen[identity] = path
        executions = []
        lines = files.get("executions.tsv", "").splitlines()
        if lines:
            header = lines[0].split("\t")
            executions = [dict(zip(header, line.split("\t"))) for line in lines[1:] if line.strip()]
        try:
            simulator = json.loads(files.get("simulator.json", "") or "{}")
        except ValueError:
            simulator = {}
        smaller = kv(files.get("smaller.txt", "")).get("device", "")
        build_id = source.get("codemagic_build_id") or next(
            (m.group(1) for m in [re.search(r"^Build\s+Codemagic (\S+?);", verdict, re.M)] if m), "")
        record = {
            "index": len(builds) + 1, "path": path,
            "scope": checkpoint.get("scope") or tests.get("scope") or "unknown",
            "head": (checkpoint.get("git_head") or source.get("git_head") or "").lower(),
            "build_id": build_id,
            "headline": next((l.strip() for l in verdict.splitlines() if l.startswith("AUTOMATED VERDICT")), ""),
            "executions": executions, "has_executions": "executions.tsv" in files,
            "model": simulator.get("device_name", ""),
            # Recorded only when both fields are present; otherwise empty, so no row of either class counts.
            "runtime": ("%s (%s)" % (simulator["runtime_name"], simulator["runtime_build"])
                        if simulator.get("runtime_name") and simulator.get("runtime_build") else ""),
            "smaller": smaller,
        }
        record["counts"], record["command"], record["check"] = product_check(record["head"], assumed)
        record["main_ok"] = record["model"] == MAIN_MODEL
        # As for main: only with a recorded runtime, so the one-runtime rule covers these rows too.
        record["small_ok"] = (smaller == SMALL_MODEL or smaller.startswith(SMALL_MODEL + " (")) and bool(record["runtime"])
        if not record["has_executions"]:
            problems.append("build [%d] %s: no executions.tsv, so none of its rows can be judged" % (record["index"], path))
        builds.append(record)
    runtimes = sorted({b["runtime"] for b in builds if b["counts"] and b["runtime"]})
    if len(runtimes) > 1:
        problems.append("the counted builds ran different runtimes, so their devices are not one class: " + "; ".join(
            "[%d] %s" % (b["index"], b["runtime"]) for b in builds if b["counts"]))

    # 3. Every execution of a counted build, by test and device class.
    by_key, ignored = {}, []
    for build in builds:
        for e in build["executions"]:
            device = e.get("device", "")
            cls = CLASS.get(device)
            record = {"build": build, "order": e.get("order", "?"), "device": device, "run": e.get("run", ""),
                      "kind": e.get("kind", ""), "outcome": e.get("outcome", ""), "seconds": e.get("seconds", ""),
                      "test": dotted(e.get("test", "")), "class": cls}
            if not build["counts"]:
                if classify(record["outcome"]) != "not run":
                    ignored.append(record)
                continue
            if cls is None:
                continue
            if cls == "main" and not build["main_ok"]:
                record["kind"] = "not counted: the build's selected simulator is %r, not an %s" % (
                    build["model"] or "not recorded", MAIN_MODEL)
            elif cls == "small" and not build["small_ok"]:
                record["kind"] = "not counted: the build's smaller iPhone is %r, not the %s" % (
                    build["smaller"] or "not recorded", SMALL_MODEL)
            by_key.setdefault((record["test"], cls), []).append(record)

    def where(e):
        return "[%d] %s %s (%s, %s%s)" % (e["build"]["index"], e["build"]["scope"], e["order"], e["kind"], e["run"],
                                          (", %s s" % e["seconds"]) if e["seconds"] else "")

    # 4. Every target: the correction's C1-C15 in number order, then the earlier rows in manifest order.
    table, status = [], {}
    applied = {RUN_TYPE_EXCEPTIONS["places:P1"]: [], DEVICE_B_EXCEPTION: []}
    position = {"%s:%s" % key: index for index, key in enumerate(manifest)}
    ordered = sorted(targets, key=lambda t: (("correction",) + EARLIER).index(t.split(":")[0]) * 10000 + (
        natural(t.split(":")[1])[1] if t.startswith("correction:") else position[t]))
    for target in ordered:
        row, entry = targets[target], coverage.get(target, {})
        cls = CLASS.get(row["device"], "?")
        found = by_key.get((dotted(row["test"]), cls), [])
        # A planned repeat (B14) is a second execution from a fresh app and runner: only an execution of
        # kind repeat stands for it, never the execution of the row it repeats.
        counting = ("repeat",) if row["kind"] == "repeat" else ("required", "extra")
        passes, failures, others = [], [], []
        for e in found:
            kind = classify(e["outcome"])
            if e["kind"].startswith("not counted"):
                others.append("%s: %s" % (where(e), e["outcome"]))
            elif kind == "failure" and e["kind"] != "diagnostic":
                failures.append(e)
            elif kind == "passed" and e["kind"] in counting:
                if run_type(e["run"]) == run_type(row["run"]) or target in RUN_TYPE_EXCEPTIONS:
                    passes.append(e)
                else:
                    others.append("%s: passed, but with %s, not %s (not the same check)" % (
                        where(e), run_type(e["run"]), run_type(row["run"])))
            elif kind == "passed":
                others.append("%s: passed, but %s" % (where(e), "a planned repeat needs an execution of its own (kind "
                                                      "repeat)" if row["kind"] == "repeat" else "its kind does not count"))
            else:
                others.append("%s: %s" % (where(e), e["outcome"]))
        if failures:
            result = "FAILED: " + "; ".join("%s: %s" % (where(e), e["outcome"]) for e in failures)
            state = "failed"
        elif passes:
            first = passes[0]
            result = "PASSED: " + "; ".join(where(e) for e in passes)
            state = "passed"
            if run_type(first["run"]) != run_type(row["run"]):
                applied[RUN_TYPE_EXCEPTIONS[target]].append(target)
            if first["device"] == "b" and row["device"] == "main":
                applied[DEVICE_B_EXCEPTION].append(target)
            elif first["device"] != row["device"]:
                applied.setdefault("rows run on the selected simulator instead of device B (its clone: the same model "
                                   "and runtime)", []).append(target)
        elif entry.get("scope") == "pending":
            result = "PENDING: not scheduled in any recovery build" + ("; seen: " + "; ".join(others) if others else "")
            state = "pending"
        else:
            result = "NOT COVERED: " + ("; ".join(others) if others else "no execution in the builds given")
            state = "missing"
        status[target] = state
        expected = ("pending, not scheduled" if entry.get("scope") == "pending" else
                    "build %s %s %s %s" % (entry.get("build", "?"), entry.get("scope", "?"), entry.get("run", "?"),
                                           entry.get("row", "?")) if entry else "not in the coverage file")
        table.append([target, "required" if row["kind"] == "required" else "optional", cls, row["test"], expected, result])

    # 5. The two verdicts.
    correction = [t for t in ordered if t.startswith("correction:")]
    earlier = [t for t in ordered if not t.startswith("correction:") and targets[t]["kind"] == "required"]
    optional = [t for t in ordered if targets[t]["kind"] != "required"]
    test_mode = sorted({b["head"] for b in builds if b["counts"] and b["head"] in assumed})
    marker = (" [TEST MODE: git_head %s assumed product-equivalent without git; not a real result]" % ", ".join(
        h[:12] for h in test_mode)) if test_mode else ""
    structural = (" and %d reconciliation problem(s) (see Problems)" % len(problems)) if problems else ""

    def listing(names):
        return ", ".join(t.split(":")[1] if t.startswith("correction:") else t for t in names)

    c_failed = [t for t in correction if status[t] == "failed"]
    c_missing = [t for t in correction if status[t] != "passed" and t not in c_failed]
    c_passed = len(correction) - len(c_failed) - len(c_missing)
    if not c_failed and not c_missing and not problems:
        targeted = "PASS (C1-C15: %d of %d passed at product-equivalent commits; none failed)%s" % (
            c_passed, len(correction), marker)
    else:
        targeted = "FAIL (%d of %d passed%s%s%s)%s" % (
            c_passed, len(correction), ("; failed: " + listing(c_failed)) if c_failed else "",
            ("; missing: " + listing(c_missing)) if c_missing else "", structural, marker)
    e_failed = [t for t in earlier if status[t] == "failed"]
    e_uncovered = [t for t in earlier if status[t] in ("pending", "missing")]
    covered = len(earlier) - len(e_failed) - len(e_uncovered)

    def why(t):
        return "%s (%s)" % (t, "pending, not scheduled" if status[t] == "pending" else "not covered")
    if e_failed or problems:
        full = "FAIL (%d of %d earlier required executions covered%s%s%s)%s" % (
            covered, len(earlier), ("; failed: " + ", ".join(e_failed)) if e_failed else "",
            ("; uncovered: " + ", ".join(why(t) for t in e_uncovered)) if e_uncovered else "", structural, marker)
    elif e_uncovered:
        full = "INCOMPLETE (%d of %d earlier required executions covered, none failed; uncovered: %s)%s" % (
            covered, len(earlier), ", ".join(why(t) for t in e_uncovered), marker)
    else:
        full = "PASS (%d of %d earlier required executions covered; none failed)%s" % (covered, len(earlier), marker)

    # 6. The report.
    out = ["Places recovery, row by row: %d build(s) given; reference commit %s" % (len(builds), REFERENCE),
           "Product and test paths compared: " + " ".join(PRODUCT_PATHS), "",
           "Builds (build-level verdicts are informational; only product-equivalent builds count):"]
    for b in builds:
        tally = {}
        for e in b["executions"]:
            tally[classify(e.get("outcome", ""))] = tally.get(classify(e.get("outcome", "")), 0) + 1
        out += ["  [%d] %s" % (b["index"], b["path"]),
                "      scope %s; %s; git_head %s" % (b["scope"], ("Codemagic " + b["build_id"]) if b["build_id"]
                                                    else "build id not recorded", b["head"] or "not recorded"),
                "      own verdict: %s" % (b["headline"] or "not supplied"),
                "      devices: selected %s, %s; smaller %s" % (b["model"] or "not recorded", b["runtime"] or "runtime not "
                                                                  "recorded", b["smaller"] or "not recorded or not used"),
                "      $ " + b["command"],
                "        " + b["check"],
                "      executions listed: %d (%s)" % (len(b["executions"]), ", ".join(
                    "%d %s" % (n, k) for k, n in sorted(tally.items())) or "none")]
    out += ["", "Rows (%d targets: %d correction, %d earlier required, %d optional):" % (
        len(ordered), len(correction), len(earlier), len(optional))]
    width = max(len(t) for t in ordered) if ordered else 10
    for target, requirement, cls, test, expected, result in table:
        out.append("  %-*s  %-8s  %-5s  %-44s  %s" % (width, target, requirement, cls, expected, result))
    out += ["", "Identity exceptions (stated and accepted), and the passed rows they applied to:"]
    out += ["  %s: %s" % (text, ", ".join(names) or "not applied in the builds given") for text, names in applied.items()]
    if ignored:
        out += ["", "Executions not counted (their build is not product-equivalent to %s, or never counts):" % REFERENCE[:12]]
        out += ["  %s %s: %s" % (where(e), e["test"], e["outcome"]) for e in ignored]
    if optional:
        out += ["", "Optional, part of no verdict: " + "; ".join("%s %s" % (t, status[t]) for t in optional)]
    if notes:
        out += ["", "Notes:"] + ["  " + n for n in notes]
    if problems:
        out += ["", "Problems (%d):" % len(problems)] + ["  " + p for p in problems]
    out += ["", "TARGETED CORRECTION: " + targeted, "FULL REGRESSION: " + full]
    print("\n".join(out))
    if tsv_path:
        with open(tsv_path, "w", encoding="utf-8") as handle:
            handle.write("target\trequirement\tclass\ttest\texpected\tresult\n")
            for cells in table:
                handle.write("\t".join(str(c).replace("\t", " ") for c in cells) + "\n")
    if targeted.startswith("PASS") and full.startswith("PASS"):
        return 0
    if targeted.startswith("PASS") and full.startswith("INCOMPLETE"):
        return 3
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

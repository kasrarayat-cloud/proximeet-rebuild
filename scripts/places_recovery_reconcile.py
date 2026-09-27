#!/usr/bin/env python3
"""Proximeet Places recovery: join the three builds' results and say whether the recovery passed.

    python3 scripts/places_recovery_reconcile.py [--manifest PATH] [--coverage PATH] [--expect-sha SHA]
                                                 [--tsv OUT] BUILD [BUILD ...]

The recovery after the Places correction is three builds on one frozen commit, in this order:
correction (the correction gate), sweep, regressions; docs/verification/places-recovery-coverage.tsv
numbers them recovery builds 2, 3 and 4 (build 1, the first correction build 6ab8adb4, ran on an
earlier commit and counts toward none of it). Each BUILD is one build's results: its downloaded
review archive (Places-Correction-Review.zip, Places-Sweep-Review.zip or Places-Regressions-Review.zip),
the folder that archive unpacks to, or a folder holding the build's results (build/artifacts itself
works). From each it reads executions.tsv, source-checkpoint.txt (git_head and scope; failing that
metadata/source.txt's git_head and ui-review-tests.txt's scope), verdict.txt and
places-review-manifest.tsv where present.

It first checks docs/verification/places-recovery-coverage.tsv (--coverage) against
docs/verification/places-review-manifest.tsv (--manifest): every row of the three scopes listed once
with the same device, run, test and kind and its scope's build number, the plan's row counts (15
correction, 22 sweep and 27 regressions required rows, 64 in all; 56 earlier required executions),
and every "covers" target an earlier row of the places, signal or regressions scope with the same
test, on the same device, in the same run type (a recorded "journey" run keeps full holds; every other
run uses short holds) and of the same kind. Then it prints one line per execution of the three builds
and exits 0 only when all of these hold:
- one build of each of the three scopes was given, and all three name the same 40-hex git_head (the
  one given by --expect-sha, when given) and ran the manifest given here;
- every required row of the three scopes (64) executed once, on its device, and passed;
- no optional row (a repeat or an extra) that ran failed, and no build executed a test outside its rows
  (a diagnostic row would only be reported; none is in the manifest since the scroll probe's rows were
  removed);
- every build's own verdict, where one was supplied, is PASS;
- all 56 earlier required executions (13 places, 16 signal, 27 regressions) are covered by a passed
  required row.
Otherwise it lists exactly which rows are missing, failed, interrupted or not run, which SHAs differ
and anything else that failed, and exits 1. A usage error exits 2. --tsv also writes the joined table.
A build of a retired scope (sweep_places, sweep_signal) or of any other scope is refused as not one of
the three. Standard library only; Python 3.8+.
"""
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "docs/verification/places-review-manifest.tsv")
COVERAGE = os.path.join(ROOT, "docs/verification/places-recovery-coverage.tsv")
RECOVERY = ("correction", "sweep", "regressions")
# Each scope's build number in the coverage file (build 1 was the first correction build, on an earlier
# commit), and the plan's required rows per scope.
BUILD = {"correction": "2", "sweep": "3", "regressions": "4"}
PLAN_REQUIRED = {"correction": 15, "sweep": 22, "regressions": 27}
PLAN_EARLIER = 56
EARLIER = ("places", "signal", "regressions")
WANTED = ("executions.tsv", "source-checkpoint.txt", "verdict.txt", "ui-review-tests.txt", "source.txt",
          "places-review-manifest.tsv")


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


def load_build(path):
    """The build's result files, by base name: {name: text}. Prefers the shallowest match; source.txt
    only from a metadata folder."""
    found = {}

    def take(name, depth, reader):
        base = name.rsplit("/", 1)[-1]
        if base not in WANTED or (base == "source.txt" and "metadata/" not in name):
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


def main(argv):
    args, builds = argv[1:], []
    manifest_path, coverage_path, expect, tsv_path = MANIFEST, COVERAGE, "", ""
    while args:
        arg = args.pop(0)
        if arg in ("--manifest", "--coverage", "--expect-sha", "--tsv") and args:
            value = args.pop(0)
            if arg == "--manifest":
                manifest_path = value
            elif arg == "--coverage":
                coverage_path = value
            elif arg == "--expect-sha":
                expect = value.strip().lower()
            else:
                tsv_path = value
        elif arg in ("-h", "--help"):
            sys.stdout.write(__doc__)
            return 0
        elif arg.startswith("--"):
            sys.stderr.write("unknown option %s\n\n%s" % (arg, __doc__))
            return 2
        else:
            builds.append(arg)
    if not builds:
        sys.stderr.write(__doc__)
        return 2
    if expect and not re.fullmatch(r"[0-9a-f]{40}", expect):
        sys.stderr.write("--expect-sha must be a full 40-hex SHA\n")
        return 2
    try:
        manifest_text = open(manifest_path, encoding="utf-8").read()
        coverage_text = open(coverage_path, encoding="utf-8").read()
    except OSError as error:
        sys.stderr.write("%s\n" % error)
        return 2

    problems, notes = [], []
    manifest = {}
    for cells in rows_of(manifest_text):
        if len(cells) != 8:
            problems.append("manifest line with %d columns, not 8: %s" % (len(cells), "\t".join(cells)))
            continue
        scope, order, device, run, bundle, seconds, test, kind = cells
        manifest[(scope, order)] = {"scope": scope, "order": order, "device": device, "run": run, "test": test,
                                    "kind": kind}

    # 1. The coverage file against the manifest.
    coverage = []
    for cells in rows_of(coverage_text):
        if cells[0] == "row":
            continue
        if len(cells) != 8:
            problems.append("coverage line with %d columns, not 8: %s" % (len(cells), "\t".join(cells)))
            continue
        order, build, scope, device, run, test, kind, covers = cells
        coverage.append({"order": order, "build": build, "scope": scope, "device": device, "run": run, "test": test,
                         "kind": kind, "covers": [c.strip() for c in covers.split(",") if c.strip() not in ("", "-")]})
    listed = {}
    for entry in coverage:
        key = (entry["scope"], entry["order"])
        if key in listed:
            problems.append("coverage lists %s %s twice" % key)
        listed[key] = entry
        row = manifest.get(key)
        if entry["scope"] not in RECOVERY:
            problems.append("coverage row %s names scope %r, not one of the three builds" % (entry["order"], entry["scope"]))
        elif entry["build"] != BUILD[entry["scope"]]:
            problems.append("coverage row %s %s says build %s; %s is build %s" % (
                entry["scope"], entry["order"], entry["build"], entry["scope"], BUILD[entry["scope"]]))
        if row is None:
            problems.append("coverage row %s %s is not in the manifest" % key)
            continue
        for field in ("device", "run", "test", "kind"):
            if entry[field] != row[field]:
                problems.append("coverage row %s %s: %s %r, but the manifest says %r" % (
                    key + (field, entry[field], row[field])))
        for target in entry["covers"]:
            scope, _, order = target.partition(":")
            earlier = manifest.get((scope, order))
            if scope not in EARLIER or earlier is None:
                problems.append("coverage row %s %s covers %s, which is not a places, signal or regressions row" % (
                    key + (target,)))
                continue
            for label, mine, theirs in (("test", entry["test"], earlier["test"]), ("device", entry["device"], earlier["device"]),
                                        ("run type", run_type(entry["run"]), run_type(earlier["run"])),
                                        ("kind", entry["kind"], earlier["kind"])):
                if mine != theirs:
                    problems.append("coverage row %s %s covers %s, but its %s is %r, not %r: not the same check" % (
                        key + (target, label, mine, theirs)))
    for key, row in sorted(manifest.items()):
        if row["scope"] in RECOVERY and key not in listed:
            problems.append("manifest row %s %s is missing from the coverage file" % key)
    earlier_required = [row for row in manifest.values() if row["scope"] in EARLIER and row["kind"] == "required"]
    # The plan's counts, so a row dropped from both the manifest and the coverage file cannot pass unseen.
    for scope in RECOVERY:
        planned = sum(1 for entry in coverage if entry["scope"] == scope and entry["kind"] == "required")
        if planned != PLAN_REQUIRED[scope]:
            problems.append("the coverage file lists %d required %s rows; the recovery plan has %d" % (
                planned, scope, PLAN_REQUIRED[scope]))
    if len(earlier_required) != PLAN_EARLIER:
        problems.append("the manifest has %d earlier required executions; the recovery plan covers %d" % (
            len(earlier_required), PLAN_EARLIER))

    # 2. The builds.
    by_scope = {}
    for path in builds:
        try:
            files = load_build(path)
        except (OSError, zipfile.BadZipFile) as error:
            problems.append("%s: unreadable (%s)" % (path, error))
            continue
        checkpoint, tests = kv(files.get("source-checkpoint.txt", "")), kv(files.get("ui-review-tests.txt", ""))
        scope = checkpoint.get("scope") or tests.get("scope") or ""
        head = checkpoint.get("git_head") or kv(files.get("source.txt", "")).get("git_head") or ""
        verdict = files.get("verdict.txt", "")
        headline = next((l.strip() for l in verdict.splitlines() if l.startswith("AUTOMATED VERDICT")), "")
        build_id = next((m.group(1) for m in [re.search(r"^Build\s+Codemagic (\S+?);", verdict, re.M)] if m), "")
        executions = []
        lines = files.get("executions.tsv", "").splitlines()
        if lines:
            header = lines[0].split("\t")
            executions = [dict(zip(header, line.split("\t"))) for line in lines[1:] if line.strip()]
        record = {"path": path, "scope": scope, "head": head, "headline": headline, "build_id": build_id,
                  "executions": executions, "has_executions": "executions.tsv" in files,
                  "manifest": files.get("places-review-manifest.tsv")}
        if scope not in RECOVERY:
            problems.append("%s: scope %r is not one of the three builds (%s)" % (path, scope or "unknown", ", ".join(RECOVERY)))
            continue
        if scope in by_scope:
            problems.append("two builds of scope %s were given: %s and %s" % (scope, by_scope[scope]["path"], path))
            continue
        by_scope[scope] = record
        if not record["has_executions"]:
            problems.append("build %s (%s): no executions.tsv, so none of its rows can be judged" % (scope, path))
        if record["manifest"] is not None and record["manifest"] != manifest_text:
            problems.append("build %s (%s) ran a manifest that differs from %s" % (scope, path, manifest_path))
        if not headline:
            notes.append("build %s (%s): no verdict.txt supplied; its own verdict was not read" % (scope, path))
        elif not headline.startswith("AUTOMATED VERDICT: PASS"):
            problems.append("build %s verdict is not PASS: %s" % (scope, headline))
    for scope in RECOVERY:
        if scope not in by_scope:
            problems.append("no build of scope %s (build %s) was given" % (scope, BUILD[scope]))

    # 3. One commit.
    heads = {scope: record["head"] for scope, record in by_scope.items()}
    for scope, head in sorted(heads.items()):
        if not re.fullmatch(r"[0-9a-f]{40}", head):
            problems.append("build %s names no full git_head (%r)" % (scope, head or "none"))
    distinct = sorted(set(heads.values()))
    if len(distinct) > 1:
        problems.append("the builds ran different commits: " + "; ".join(
            "%s %s" % (scope, heads[scope]) for scope in RECOVERY if scope in heads))
    if expect:
        for scope, head in sorted(heads.items()):
            if head != expect:
                problems.append("build %s ran %s, not the expected %s" % (scope, head or "an unknown commit", expect))
    common = distinct[0] if len(distinct) == 1 else ""
    one_commit = len(by_scope) == len(RECOVERY) and bool(re.fullmatch(r"[0-9a-f]{40}", common)) and \
        (not expect or common == expect)

    # 4. Every execution of the three builds.
    table, passed_rows = [], set()
    for entry in coverage:
        record = by_scope.get(entry["scope"])
        found = [e for e in (record["executions"] if record else []) if e.get("order") == entry["order"]]
        seconds = ""
        if record is None:
            outcome = "not run (no %s build was given)" % entry["scope"]
        elif not record["has_executions"]:
            outcome = "not judged (the build has no executions.tsv)"
        elif not found:
            outcome = "missing (not in the build's executions.tsv)"
        else:
            execution = found[0]
            outcome, seconds = execution.get("outcome", "") or "missing (no outcome)", execution.get("seconds", "")
            if execution.get("test", "").replace("/", ".") != entry["test"].replace("/", "."):
                outcome = "mismatch (the build ran %s as %s)" % (execution.get("test", "?"), entry["order"])
            elif execution.get("device") and execution.get("device") != entry["device"]:
                outcome = "mismatch (ran on %s, not %s)" % (execution.get("device"), entry["device"])
            if len(found) > 1:
                outcome += " (listed %d times)" % len(found)
        ok = outcome == "passed"
        if entry["kind"] == "required":
            if ok:
                passed_rows.add((entry["scope"], entry["order"]))
            else:
                problems.append("build %s %s %s %s (%s, required): %s" % (
                    entry["build"], entry["scope"], entry["order"], entry["test"], entry["device"], outcome))
        elif entry["kind"] == "diagnostic":
            pass  # a diagnostic (none in the manifest now): reported in the table, never part of the verdict
        elif not ok and not outcome.startswith(("not run", "not judged")):
            problems.append("build %s %s %s %s (%s, %s, optional; if it runs it must pass): %s" % (
                entry["build"], entry["scope"], entry["order"], entry["test"], entry["device"], entry["kind"], outcome))
        table.append([entry["build"], entry["scope"], entry["order"], entry["device"], entry["run"], entry["kind"],
                      ",".join(entry["covers"]) or "-", outcome, seconds, entry["test"]])
    for scope, record in sorted(by_scope.items()):
        rows = {entry["order"] for entry in coverage if entry["scope"] == scope}
        for e in record["executions"]:
            if e.get("order") not in rows:
                problems.append("build %s executed %s outside its rows (%s): %s" % (
                    scope, e.get("test", "?"), e.get("order", "?"), e.get("outcome", "?")))

    # 5. The 56 earlier required executions.
    uncovered = []
    for row in sorted(earlier_required, key=lambda r: (EARLIER.index(r["scope"]), natural(r["order"]))):
        target = "%s:%s" % (row["scope"], row["order"])
        by = [entry for entry in coverage if target in entry["covers"] and entry["kind"] == "required"]
        if not any((entry["scope"], entry["order"]) in passed_rows for entry in by):
            uncovered.append("%s (%s)" % (target, ", ".join("%s %s" % (e["scope"], e["order"]) for e in by) or "listed nowhere"))
    if uncovered:
        problems.append("%d of %d earlier required executions are not covered by a passed required row: %s" % (
            len(uncovered), len(earlier_required), "; ".join(uncovered)))

    required = [entry for entry in coverage if entry["kind"] == "required"]
    widths = [5, 12, 4, 6, 18, 8, 12, 0]
    out = ["Places recovery: %d builds given, %d executions listed (%d required)" % (len(builds), len(coverage), len(required)),
           ""]
    out.append("  ".join(h.ljust(w) for h, w in zip(("build", "scope", "row", "device", "run", "kind", "covers", "outcome"),
                                                     widths)).rstrip())
    for cells in table:
        line = "  ".join(str(c).ljust(w) for c, w in zip(cells[:8], widths)).rstrip()
        out.append(line + (" (%s s)" % cells[8] if cells[8] else ""))
    out += ["", "Builds:"]
    for scope in RECOVERY:
        record = by_scope.get(scope)
        out.append("  %s %-12s %s" % (BUILD[scope], scope, (
            "git_head=%s  %s  %s  (%s)" % (record["head"] or "unknown", ("Codemagic " + record["build_id"]) if record["build_id"]
                                           else "build id not read", record["headline"] or "verdict not supplied",
                                           record["path"])) if record else "NOT GIVEN"))
    out += ["",
            "One commit: " + (common if one_commit else "NO (%s)" % (
                "; ".join("%s %s" % (s, heads[s] or "unknown") for s in RECOVERY if s in heads) or "no builds")),
            "Required rows passed: %d of %d" % (len(passed_rows), len(required)),
            "Earlier required executions covered: %d of %d" % (len(earlier_required) - len(uncovered), len(earlier_required))]
    if notes:
        out += ["", "Notes:"] + ["  " + n for n in notes]
    if problems:
        out += ["", "Problems (%d):" % len(problems)] + ["  " + p for p in problems]
    out += ["", "RECOVERY: " + ("PASS (three builds, one commit %s; every required row passed; manual review still "
                                "outstanding)" % common if not problems else "FAIL (%d problems)" % len(problems))]
    print("\n".join(out))
    if tsv_path:
        with open(tsv_path, "w", encoding="utf-8") as handle:
            handle.write("build\tscope\trow\tdevice\trun\tkind\tcovers\toutcome\tseconds\ttest\n")
            for cells in table:
                handle.write("\t".join(str(c).replace("\t", " ") for c in cells) + "\n")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

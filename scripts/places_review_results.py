#!/usr/bin/env python3
"""Proximeet Places review: what actually ran in one scope, judged against the manifest.

    python3 scripts/places_review_results.py MANIFEST SCOPE RUNS OUT_TXT OUT_TSV MAIN_UDID B_UDID SMALL_UDID LOG [LOG ...]

MANIFEST is docs/verification/places-review-manifest.tsv; only the rows of SCOPE (correction, sweep,
regressions, places or signal) are judged; a scope with no rows is a FAIL. RUNS is the stage's runs.txt
("<run> <bundle> <exit> <kind>", kind no | infra | time | device). The LOGs are the lanes' xcodebuild
logs, in which every run starts with a "$ ..." line naming its destination and result bundle. B_UDID
or SMALL_UDID may be "" when that device was not used (device B's rows then run on the selected
simulator). Writes the key=value results that scripts/places_review.sh's verdict reads (OUT_TXT) and
one row per manifest row and per unexpected execution (OUT_TSV). Exits 0 whether the result is PASS
or FAIL; the verdict decides.

Automatic retries are off in every scope, so every execution counts: a required test passes only if
its run executed it exactly once, on its device, and it passed. A planned repeat is its own row; it
may be left unrun for time (runs.txt says so), but if it runs it must pass; so may an extra. A
diagnostic row starts like an extra, but its outcome and its run's exit are only reported: they never
count toward the verdict (no manifest row is a diagnostic since the correction's scroll probe rows,
runs probe_*, were removed; the handling stays for any later one). A skipped test, an interrupted one
(started, no outcome) and a run that did not exit 0 are failures. Standard library only; Python 3.8+.
"""
import os
import re
import sys

CASE = re.compile(r"Test [Cc]ase '(?:-\[)?(?:\w+\.)?(\w+Tests)[ ./](test\w+)(?:\(\))?\]?' "
                  r"(started|passed|failed|skipped)(?: \(([\d.]+) seconds\))?")
ERROR = re.compile(r": error: -\[(?:\w+\.)?(\w+Tests) (test\w+)\] : (.*)$")
COMMAND = re.compile(r"^\$ .*-destination platform=iOS Simulator,id=([0-9A-Fa-f-]{36})")
BUNDLE = re.compile(r"-resultBundlePath \S*?(\w+)\.xcresult")
FLAGS = ("PLACES", "SIGNAL", "WRISTBAND", "GUEST_LIST", "PASS", "BIRTHDAY", "WELCOME")
LANE_LABEL = {"main": "main", "b": "deviceB", "small": "smaller"}


def kind_label(row):
    """The row's kind as reported: the scroll probe is a diagnostic that never counts toward a verdict."""
    if row["kind"] == "diagnostic" or (row["kind"] == "extra" and row["run"].startswith("probe_")):
        return "diagnostic (optional; never part of the verdict)"
    return row["kind"]


def load_manifest(path, scope):
    rows = []
    for line in open(path, encoding="utf-8"):
        if not line.strip() or line.startswith("#"):
            continue
        row_scope, order, device, run, bundle, seconds, test, kind = line.rstrip("\n").split("\t")
        if row_scope == scope:
            rows.append({"order": order, "device": device, "run": run, "bundle": bundle, "seconds": seconds,
                         "test": test.replace("/", "."), "kind": kind})
    return rows


def load_runs(path):
    runs = []
    if os.path.isfile(path):
        for line in open(path, encoding="utf-8"):
            parts = line.split()
            if len(parts) == 4:
                runs.append({"run": parts[0], "bundle": parts[1], "exit": parts[2], "kind": parts[3]})
    return runs


def parse_logs(paths):
    """Every test event, in order, keyed by result bundle: {bundle: [(device, test, event, seconds)]}."""
    events, errors, markers, walk_start = {}, {}, set(), None
    for path in paths:
        if not os.path.isfile(path):
            continue
        device, bundle = None, None
        for line in open(path, encoding="utf-8", errors="replace"):
            started = COMMAND.search(line)
            if started:
                device = started.group(1).upper()
                named = BUNDLE.search(line)
                bundle = named.group(1) if named else None
                continue
            match = CASE.search(line)
            if match and bundle:
                test = "%s.%s" % (match.group(1), match.group(2))
                events.setdefault(bundle, []).append((device, test, match.group(3), match.group(4)))
                continue
            failure = ERROR.search(line)
            if failure and bundle:
                errors.setdefault((bundle, "%s.%s" % failure.group(1, 2)), []).append(failure.group(3).strip())
            for flag in FLAGS:
                if flag + "_REVIEW_FLAG_SEEN" in line:
                    markers.add(flag.lower())
            begun = re.search(r"PLACES_WALKTHROUGH_START (\d+(?:\.\d+)?)", line)
            if begun and walk_start is None:
                walk_start = begun.group(1)
    return events, errors, markers, walk_start


def executions(bundle_events):
    """One record per started test: outcome passed/failed/skipped, or interrupted when no outcome followed."""
    out, open_run = [], {}
    for device, test, event, seconds in bundle_events:
        if event == "started":
            if test in open_run:
                out.append(open_run.pop(test))
            open_run[test] = {"device": device, "test": test, "outcome": "interrupted", "seconds": None}
        else:
            record = open_run.pop(test, None) or {"device": device, "test": test}
            record.update(outcome=event, seconds=seconds)
            out.append(record)
    out.extend(open_run.values())
    return out


def main(argv):
    if len(argv) < 10:
        sys.stderr.write(__doc__)
        return 2
    manifest_path, scope, runs_path, out_txt, out_tsv, main_udid, b_udid, small_udid = argv[1:9]
    logs = argv[9:]
    rows = load_manifest(manifest_path, scope)
    runs = load_runs(runs_path)
    events, errors, markers, walk_start = parse_logs(logs)
    main_udid = main_udid.upper()
    b_used = bool(b_udid)
    lane_udid = {"main": main_udid, "b": (b_udid or main_udid).upper(), "small": small_udid.upper()}

    by_bundle = {bundle: executions(evts) for bundle, evts in events.items()}
    manifest_keys = {(r["bundle"], r["test"]) for r in rows}
    problems, table, result_lines, repeats = [], [], [], []
    run_exit = {r["run"]: r for r in runs if r["kind"] != "infra"}

    if not rows:
        problems.append("the manifest has no rows for scope %r" % scope)
    for row in rows:
        found = [e for e in by_bundle.get(row["bundle"], []) if e["test"] == row["test"]]
        expected_device = lane_udid[row["device"]]
        run = run_exit.get(row["run"])
        messages = errors.get((row["bundle"], row["test"]), [])
        seconds = None
        if not found:
            if row["kind"] in ("repeat", "extra", "diagnostic") and run and run["kind"] == "time":
                outcome = "not run (time budget: optional, left for the required runs)"
            elif run is None:
                outcome = "not run (its run was not started)"
            elif run["kind"] == "device":
                outcome = "not run (no %s device)" % LANE_LABEL[row["device"]]
            else:
                outcome = "not run (run %s ended with exit %s before this test started)" % (row["run"], run["exit"])
            if row["kind"] == "required":
                problems.append("%s %s: %s" % (row["order"], row["test"], outcome))
        else:
            execution = found[0]
            outcome, seconds = execution["outcome"], execution["seconds"]
            if len(found) > 1:
                outcome = " then ".join(e["outcome"] for e in found) + " (%d executions in one run)" % len(found)
                problems.append("%s %s: executed %d times in %s; retries are off" % (
                    row["order"], row["test"], len(found), row["bundle"]))
            elif outcome != "passed" and row["kind"] != "diagnostic":
                problems.append("%s %s: %s%s" % (row["order"], row["test"], outcome + (
                    " (started, no outcome recorded: a time bound, a runner crash or restart)"
                    if outcome == "interrupted" else ""), (": " + messages[0]) if messages else ""))
            if row["kind"] == "diagnostic":
                pass
            elif not expected_device:
                problems.append("%s %s: ran, but no %s device was recorded" % (row["order"], row["test"],
                                                                          LANE_LABEL[row["device"]]))
            elif execution["device"] and execution["device"] != expected_device:
                problems.append("%s %s: ran on %s, not on %s" % (row["order"], row["test"], execution["device"],
                                                                expected_device))
            label = LANE_LABEL[row["device"]] + ((", " + kind_label(row)) if row["kind"] != "required" else "")
            result_lines.append("%s[%s]=%s%s" % (row["test"], label, outcome, (" (%s s)" % seconds) if seconds else ""))
        if row["kind"] != "required":
            repeats.append("%s %s (%s, %s): %s" % (row["order"], row["test"], kind_label(row), LANE_LABEL[row["device"]],
                                                   outcome))
        table.append([row["order"], row["device"], expected_device, row["run"], row["bundle"], row["test"], row["kind"],
                      outcome, seconds or "", " | ".join(messages)])

    unexpected = [(bundle, e) for bundle, found in by_bundle.items() for e in found
                  if (bundle, e["test"]) not in manifest_keys]
    for bundle, e in unexpected:
        problems.append("unexpected execution %s in %s: %s" % (e["test"], bundle, e["outcome"]))
        table.append(["-", "-", e["device"] or "", "-", bundle, e["test"], "unexpected", e["outcome"], e["seconds"] or "",
                      " | ".join(errors.get((bundle, e["test"]), []))])

    for name in sorted({r["run"] for r in rows}):
        run = run_exit.get(name)
        kinds = {r["kind"] for r in rows if r["run"] == name}
        optional = kinds <= {"repeat", "extra", "diagnostic"}
        diagnostic = kinds == {"diagnostic"}
        if run is None:
            if not optional:
                problems.append("run %s has no recorded exit (it did not run)" % name)
        elif run["kind"] == "time":
            if not optional:
                problems.append("run %s was left unrun for time" % name)
        elif run["kind"] == "device":
            problems.append("run %s had no device to run on" % name)
        elif run["exit"] != "0" and not diagnostic:
            problems.append("run %s (bundle %s) exited %s" % (name, run["bundle"], run["exit"]))
    infra = [r for r in runs if r["kind"] == "infra"]

    # Every execution in this build's logs: the scope's rows and anything unexpected.
    all_exec = [e for found in by_bundle.values() for e in found]
    counts = {k: sum(1 for e in all_exec if e["outcome"] == k) for k in ("passed", "failed", "skipped", "interrupted")}
    executed = counts["passed"] + counts["failed"]
    unique = {e["test"] for e in all_exec if e["outcome"] in ("passed", "failed")}
    required = [r for r in rows if r["kind"] == "required"]
    required_ok = [r for r, t in zip(rows, table) if r["kind"] == "required" and t[7] == "passed"]
    ok = not problems and executed > 0

    lines = sorted(result_lines) + [
        "scope=" + scope,
        "manifest=%s (%d rows for this scope: %d required, %d optional)" % (
            os.path.basename(manifest_path), len(rows), len(required), len(rows) - len(required)),
        "unique_test_cases=%d" % len(unique),
        "executions=%d" % executed,
        "passed=%(passed)d" % counts, "failed=%(failed)d" % counts, "skipped=%(skipped)d" % counts,
        "interrupted=%(interrupted)d" % counts,
        "first_attempt_required=%d of %d required executions passed on their first and only attempt" % (
            len(required_ok), len(required)),
        "required_passed=" + ("yes" if len(required_ok) == len(required) and not problems else
                              "no (" + "; ".join(problems) + ")"),
        "retries=off (no -retry-tests-on-failure in any scope)",
        "retried=" + ("; ".join(p for p in problems if "retries are off" in p) or "none"),
        "repeats=" + ("; ".join(repeats) if repeats else "none planned"),
        "infrastructure_reruns=" + ("; ".join("%s (bundle %s): xcodebuild exit %s, simulator not found, no test ran; "
                                              "the same tests ran again" % (r["run"], r["bundle"], r["exit"])
                                              for r in infra) if infra else "none"),
        "flag_markers_in_log=" + " ".join(sorted(markers)),
        "walkthrough_started_epoch=%s" % (walk_start or ("unknown" if any(r["run"] == "journey" for r in rows)
                                                         else "not recorded in this scope")),
        "devices=main %s; device B %s; smaller %s" % (main_udid, b_udid.upper() if b_used else "not used",
                                                     small_udid.upper() or "not used"),
    ]
    lines += ["xcodebuild_exit_%s=%s (bundle %s, %s)" % (r["run"], r["exit"], r["bundle"],
                                                        {"infra": "simulator not found, no test ran; rerun",
                                                         "time": "not started: time budget",
                                                         "device": "not started: no device",
                                                         "no": "retries off"}.get(r["kind"], r["kind"]))
              for r in runs]
    lines += ["result=" + ("PASS" if ok else "FAIL")]
    with open(out_txt, "w", encoding="utf-8") as out:
        out.write("\n".join(lines) + "\n")
    with open(out_tsv, "w", encoding="utf-8") as out:
        out.write("order\tdevice\tudid\trun\tbundle\ttest\tkind\toutcome\tseconds\tfailure\n")
        for row in table:
            out.write("\t".join(str(c).replace("\t", " ").replace("\n", " ") for c in row) + "\n")
    print("scope %s: %d unique cases, %d executions (passed %d, failed %d, skipped %d, interrupted %d); "
          "required first-attempt passes %d/%d; repeats: %s; %s"
          % (scope, len(unique), executed, counts["passed"], counts["failed"], counts["skipped"], counts["interrupted"],
             len(required_ok), len(required), "; ".join(repeats) or "none", "PASS" if ok else "FAIL"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

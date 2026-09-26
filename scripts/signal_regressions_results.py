#!/usr/bin/env python3
"""Proximeet Signal regressions scope: what actually ran, judged against the manifest.

    python3 scripts/signal_regressions_results.py MANIFEST RUNS OUT_TXT OUT_TSV MAIN_UDID B_UDID LOG [LOG ...]

MANIFEST is docs/verification/signal-regressions-recovery-manifest.tsv. RUNS is the stage's runs.txt
("<run> <bundle> <exit> <kind>", kind no | infra | time). The LOGs are the lanes' xcodebuild logs, in
which every run starts with a "$ ..." line naming its destination and result bundle. Writes the
key=value results that scripts/signal_review.sh's verdict reads (OUT_TXT) and one row per manifest
row and per unexpected execution (OUT_TSV). Exits 0 whether the result is PASS or FAIL; the verdict
decides.

Automatic retries are off in this scope, so every execution counts: a required test passes only if
its run executed it exactly once and it passed. A planned repeat is its own row; it may be left
unrun for time (runs.txt says so), but if it runs it must pass. Standard library only; Python 3.8+.
"""
import os
import re
import sys

CASE = re.compile(r"Test [Cc]ase '(?:-\[)?(?:\w+\.)?(\w+Tests)[ ./](test\w+)(?:\(\))?\]?' "
                  r"(started|passed|failed|skipped)(?: \(([\d.]+) seconds\))?")
ERROR = re.compile(r": error: -\[(?:\w+\.)?(\w+Tests) (test\w+)\] : (.*)$")
COMMAND = re.compile(r"^\$ .*-destination platform=iOS Simulator,id=([0-9A-Fa-f-]{36})")
BUNDLE = re.compile(r"-resultBundlePath \S*?(\w+)\.xcresult")


def load_manifest(path):
    rows = []
    for line in open(path, encoding="utf-8"):
        if not line.strip() or line.startswith("#"):
            continue
        order, device, run, bundle, test, kind = line.rstrip("\n").split("\t")
        rows.append({"order": order, "device": device, "run": run, "bundle": bundle,
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
    events, errors, markers = {}, {}, set()
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
            for flag in ("WRISTBAND", "GUEST_LIST", "PASS", "BIRTHDAY", "WELCOME", "SIGNAL"):
                if flag + "_REVIEW_FLAG_SEEN" in line:
                    markers.add(flag.lower())
    return events, errors, markers


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
    if len(argv) < 8:
        sys.stderr.write(__doc__)
        return 2
    manifest_path, runs_path, out_txt, out_tsv, main_udid, b_udid = argv[1:7]
    logs = argv[7:]
    rows = load_manifest(manifest_path)
    runs = load_runs(runs_path)
    events, errors, markers = parse_logs(logs)
    main_udid, b_udid = main_udid.upper(), (b_udid or main_udid).upper()
    lane_udid = {"main": main_udid, "b": b_udid}
    lane_label = {"main": "main", "b": "deviceB"}

    by_bundle = {bundle: executions(evts) for bundle, evts in events.items()}
    manifest_keys = {(r["bundle"], r["test"]) for r in rows}
    problems, table, result_lines = [], [], []
    run_exit = {}
    for run in runs:
        if run["kind"] != "infra":
            run_exit[run["run"]] = run
    repeats = []

    for row in rows:
        found = [e for e in by_bundle.get(row["bundle"], []) if e["test"] == row["test"]]
        expected_device = lane_udid[row["device"]]
        run = run_exit.get(row["run"])
        messages = errors.get((row["bundle"], row["test"]), [])
        if not found:
            if row["kind"] == "repeat" and run and run["kind"] == "time":
                outcome = "not run (time budget: left for the required run after it)"
            elif run is None:
                outcome = "not run (its run was not started)"
            else:
                outcome = "not run (run %s ended with exit %s before this test started)" % (row["run"], run["exit"])
            if row["kind"] == "required":
                problems.append("%s %s: %s" % (row["order"], row["test"], outcome))
            seconds = None
        else:
            execution = found[0]
            outcome, seconds = execution["outcome"], execution["seconds"]
            if len(found) > 1:
                outcome = " then ".join(e["outcome"] for e in found) + " (%d executions in one run)" % len(found)
                problems.append("%s %s: executed %d times in %s; retries are off in this scope" % (
                    row["order"], row["test"], len(found), row["bundle"]))
            elif outcome != "passed":
                problems.append("%s %s: %s%s" % (row["order"], row["test"], outcome + (
                    " (started, no outcome recorded: a time bound, a runner crash or restart)"
                    if outcome == "interrupted" else ""), (": " + messages[0]) if messages else ""))
            if execution["device"] and execution["device"] != expected_device:
                problems.append("%s %s: ran on %s, not on %s" % (row["order"], row["test"], execution["device"],
                                                                expected_device))
            label = lane_label[row["device"]] + (", repeat" if row["kind"] == "repeat" else "")
            result_lines.append("%s[%s]=%s%s" % (row["test"], label, outcome, (" (%s s)" % seconds) if seconds else ""))
        if row["kind"] == "repeat":
            repeats.append("%s %s: %s" % (row["order"], row["test"], outcome))
        table.append([row["order"], row["device"], expected_device, row["run"], row["bundle"], row["test"], row["kind"],
                      outcome, seconds or "", " | ".join(messages)])

    unexpected = [(bundle, e) for bundle, found in by_bundle.items() for e in found
                  if (bundle, e["test"]) not in manifest_keys]
    for bundle, e in unexpected:
        problems.append("unexpected execution %s in %s: %s" % (e["test"], bundle, e["outcome"]))
        table.append(["-", "-", e["device"] or "", "-", bundle, e["test"], "unexpected", e["outcome"], e["seconds"] or "",
                      " | ".join(errors.get((bundle, e["test"]), []))])

    ran_runs = {r["run"] for r in rows}
    for name in sorted(ran_runs):
        run = run_exit.get(name)
        kinds = {r["kind"] for r in rows if r["run"] == name}
        if run is None:
            if kinds != {"repeat"}:
                problems.append("run %s has no recorded exit (it did not run)" % name)
        elif run["kind"] == "time":
            if kinds != {"repeat"}:
                problems.append("run %s was left unrun for time" % name)
        elif run["exit"] != "0":
            problems.append("run %s (bundle %s) exited %s" % (name, run["bundle"], run["exit"]))
    infra = [r for r in runs if r["kind"] == "infra"]

    all_exec = [e for found in by_bundle.values() for e in found]
    counts = {k: sum(1 for e in all_exec if e["outcome"] == k) for k in ("passed", "failed", "skipped", "interrupted")}
    executed = counts["passed"] + counts["failed"]
    unique = {e["test"] for e in all_exec if e["outcome"] in ("passed", "failed")}
    required = [r for r in rows if r["kind"] == "required"]
    required_ok = [r for r, t in zip(rows, table) if r["kind"] == "required" and t[7] == "passed"]
    retried = [p for p in problems if "retries are off" in p]
    ok = not problems and executed > 0

    lines = sorted(result_lines) + [
        "scope=regressions",
        "manifest=%s (%d rows: %d required, %d repeat)" % (os.path.basename(manifest_path), len(rows), len(required),
                                                          len(rows) - len(required)),
        "unique_test_cases=%d" % len(unique),
        "executions=%d" % executed,
        "passed=%(passed)d" % counts, "failed=%(failed)d" % counts, "skipped=%(skipped)d" % counts,
        "interrupted=%(interrupted)d" % counts,
        "first_attempt_required=%d of %d required executions passed on their first and only attempt" % (
            len(required_ok), len(required)),
        "required_passed=" + ("yes" if len(required_ok) == len(required) and not problems else
                              "no (" + "; ".join(problems) + ")"),
        "retries=off (no -retry-tests-on-failure in this scope)",
        "retried=" + ("; ".join(retried) if retried else "none"),
        "repeats=" + ("; ".join(repeats) if repeats else "none planned"),
        "infrastructure_reruns=" + ("; ".join("%s (bundle %s): xcodebuild exit %s, simulator not found, no test ran; "
                                              "the same tests ran again" % (r["run"], r["bundle"], r["exit"])
                                              for r in infra) if infra else "none"),
        "flag_markers_in_log=" + " ".join(sorted(markers)),
        "walkthrough_started_epoch=not recorded in this scope",
        "devices=main %s; device B %s; smaller not used" % (main_udid, b_udid if b_udid != main_udid else "not used"),
    ]
    lines += ["xcodebuild_exit_%s=%s (bundle %s, %s)" % (r["run"], r["exit"], r["bundle"],
                                                        {"infra": "simulator not found, no test ran; rerun",
                                                         "time": "not started: time budget",
                                                         "no": "retries off"}.get(r["kind"], r["kind"]))
              for r in runs]
    lines += ["result=" + ("PASS" if ok else "FAIL")]
    with open(out_txt, "w", encoding="utf-8") as out:
        out.write("\n".join(lines) + "\n")
    with open(out_tsv, "w", encoding="utf-8") as out:
        out.write("order\tdevice\tudid\trun\tbundle\ttest\tkind\toutcome\tseconds\tfailure\n")
        for row in table:
            out.write("\t".join(str(c).replace("\t", " ").replace("\n", " ") for c in row) + "\n")
    print("scope regressions: %d unique cases, %d executions (passed %d, failed %d, skipped %d, interrupted %d); "
          "required first-attempt passes %d/%d; repeats: %s; %s"
          % (len(unique), executed, counts["passed"], counts["failed"], counts["skipped"], counts["interrupted"],
             len(required_ok), len(required), "; ".join(repeats) or "none", "PASS" if ok else "FAIL"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

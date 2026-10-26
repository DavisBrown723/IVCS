"""Pool precise, complete helicopter benchmark windows without averaging percentiles."""
import argparse
import csv
import importlib.util
import json
from collections import defaultdict
from pathlib import Path

from timing_guard import assert_benchmark_idle
assert_benchmark_idle()



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operations", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = json.loads(args.operations.read_text())
    if not report["eligible_for_performance_comparison"]:
        raise ValueError("Attribution is not a passing performance run")
    spec = importlib.util.spec_from_file_location("frame_stats", Path(__file__).with_name("analyze-performance.py"))
    base = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(base)
    calls = []
    for path in report["event_sources"]:
        with Path(path).open(encoding="utf-8-sig", newline="") as handle:
            for row in csv.DictReader(handle):
                calls.append((row["name"], int(row["ns_since_start"]), int(row["exec_time_ns"])))
    grouped = defaultdict(list)
    for phase in report["phases"]:
        grouped[phase["mode"]].append(phase)
    results = []
    for mode, phases in sorted(grouped.items()):
        frames = [frame for phase in phases for frame in phase["frame_attribution"]]
        metrics = {name: base.distribution([frame["costs_ms"][name] for frame in frames])
                   for name in frames[0]["costs_ms"]}
        metrics["full_busy"] = base.distribution([frame["costs_ms"]["full"] for frame in frames if frame["steps"]])
        by_name = defaultdict(list)
        for phase in phases:
            start, end = phase["begin_ns"], phase["end_ns"]
            for name, ns, elapsed in calls:
                if start <= ns and ns + elapsed <= end:
                    by_name[name].append(elapsed / 1e6)
        operations = {name: base.distribution(values) for name, values in sorted(by_name.items())}
        results.append(dict(mode=mode, groups=20, frames=len(frames), trials=len(phases),
            metrics=metrics, operations=operations,
            trial_metrics=[dict(trial=p["trial"], frames=p["frames"],
                full=base.distribution([f["costs_ms"]["full"] for f in p["frame_attribution"]])) for p in phases],
            worst_frames=sorted(frames, key=lambda f:f["costs_ms"]["full"], reverse=True)[:10]))
    output = dict(trace=report["trace"], metadata=report["metadata"],
        validity_checks=report["validity_checks"], selected_trials=report.get("selected_trials"),
        excluded_trace_windows=report.get("excluded_trace_windows",[]), results=results,
        note="Precise named scopes in complete validated windows. Component p99 values are not additive; nested operation scopes overlap.")
    args.output.write_text(json.dumps(output, indent=2) + "\n")
    for result in results:
        full = result["metrics"]["full"]
        print(result["mode"], result["frames"], "frames:",
            "mean={mean_ms:.4f} p95={p95_ms:.4f} p99={p99_ms:.4f} max={max_ms:.4f} ms".format(**full))


if __name__ == "__main__":
    main()

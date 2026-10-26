"""Validate helicopter workload metadata and summarize real EachFrame timings."""
import argparse
import importlib.util
import json
from pathlib import Path

from timing_guard import assert_benchmark_idle
assert_benchmark_idle()



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rpt", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--label", default="helicopters")
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("frame_analysis", Path(__file__).with_name("analyze-performance.py"))
    base = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(base)
    work = {}
    for line in args.rpt.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        if "[IVCS HELI PERF] WORK " in line:
            row = base.payload(line, "[IVCS HELI PERF] WORK ")
            trial, mode, groups, engagements, supporters, shots, entities, units = row
            scenario = mode.removeprefix("before-").removeprefix("after-")
            if groups != 20 or entities != (35 if scenario == "heli-vehicle-aa" else 30):
                raise ValueError("Unexpected cohort size")
            fighting = scenario != "heli-idle"
            aa = mode.endswith("-aa")
            if engagements != (5 if fighting else 0) or supporters != (10 if aa else 0):
                raise ValueError("Missing engagements or supporting AA")
            if fighting and (shots[0] <= 0 or (aa and min(shots[1:3]) <= 0)):
                raise ValueError("Missing helicopter or AA firing work")
            work[trial, mode, groups] = dict(engagements=engagements, supporters=supporters,
                helicopter_shots=shots[0], infantry_aa_shots=shots[1], vehicle_aa_shots=shots[2],
                primary_vehicle_shots=shots[3], entities=entities, units=units)
    if not work:
        raise ValueError("Missing helicopter workload metadata")
    base.main()
    output = args.output / (args.label + "-summary.json")
    report = json.loads(output.read_text())
    expected = set()
    for result in report["results"]:
        samples = []
        for phase in result["trials"]:
            key = phase["trial"], phase["mode"], phase["groups"]
            expected.add(key)
            phase["workload"] = work[key]
            if not phase["mode"].endswith("heli-idle") and "combat_progress" not in phase:
                raise ValueError("Missing combat-clock progress validation")
            samples.append(work[key])
        result["engagements"] = samples[0]["engagements"]
        result["supporters"] = samples[0]["supporters"]
        result["role_shots"] = {name: sum(s[name] for s in samples) for name in (
            "helicopter_shots", "infantry_aa_shots", "vehicle_aa_shots", "primary_vehicle_shots")}
    if expected != set(work):
        raise ValueError("Workload metadata does not match measured phases")
    report["workload_notes"] = [
        "20 total groups including helicopter crews, infantry AA teams, and AA vehicle crews; five engagements.",
        "Virtual only, production budgets, real movement, visibility, damage and ammunition selection.",
        "Test-only immortality restores vehicle health after real damage calculations and prevents unit removals; restoration overhead is included.",
        "Infantry target squads replace one member with organic AA; each infantry launcher carries 12 magazines to sustain the load.",
        "Co-located virtual battle cells create a dense-frontline scan workload; a 600 m waypoint attack radius sustains infantry contact; weapon ranges stay at production defaults.",
        "Startup, setup and teardown are excluded; timing runs are sequential and use the production frame budgets."
    ]
    output.write_text(json.dumps(report, indent=2) + "\n")
    print("Validated helicopter/AA workload metadata for", len(work), "windows")


if __name__ == "__main__":
    main()

"""Audit archived experiment records for near-zero constraint violations."""
from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESULT_ROOT = ROOT / "06_results"
TARGETS = [
    "main_30x800_v3_physics",
    "budget_30x400_v3_physics",
    "budget_30x1600_v3_physics",
    "ablation_30x800_v3_physics",
]
TOLERANCE = 1e-12


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def main():
    report = {"tolerance": TOLERANCE, "directories": {}, "total_near_zero": 0}
    for name in TARGETS:
        path = RESULT_ROOT / name / "runs.json"
        payload = json.loads(path.read_text(encoding="utf-8"))
        count_total = 0
        count_positive = 0
        count_near_zero = 0
        maximum_near_zero = 0.0
        for node in walk(payload):
            if "total_violation" not in node:
                continue
            value = float(node["total_violation"])
            count_total += 1
            if value > 0.0:
                count_positive += 1
            if 0.0 < value <= TOLERANCE:
                count_near_zero += 1
                maximum_near_zero = max(maximum_near_zero, value)
        report["directories"][name] = {
            "records_with_total_violation": count_total,
            "positive_violation_records": count_positive,
            "near_zero_violation_records": count_near_zero,
            "maximum_near_zero_violation": maximum_near_zero,
        }
        report["total_near_zero"] += count_near_zero
    out = RESULT_ROOT / "structural_reduction_verification" / "constraint_tolerance_audit.json"
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

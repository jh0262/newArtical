"""Compare frozen-seed v3 and tolerance-aware v4 result archives.

Only scientific result fields are compared. Directory labels and execution
metadata are intentionally excluded because they are expected to differ.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "06_results"
OUTPUT = RESULTS / "structural_reduction_verification" / "tolerance_rerun_comparison.json"

PAIRS = {
    "main_30x800": ("main_30x800_v3_physics", "main_30x800_v4_tolerance"),
    "budget_30x400": ("budget_30x400_v3_physics", "budget_30x400_v4_tolerance"),
    "budget_30x1600": ("budget_30x1600_v3_physics", "budget_30x1600_v4_tolerance"),
    "ablation_30x800": ("ablation_30x800_v3_physics", "ablation_30x800_v4_tolerance"),
}


def load_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    return sorted(rows, key=lambda row: (row.get("method", ""), int(row.get("seed", 0))))


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def scientific_analysis(path: Path):
    payload = load_json(path)
    payload.pop("directory", None)
    return payload


def main() -> None:
    comparisons = {}
    for label, (old_name, new_name) in PAIRS.items():
        old_dir = RESULTS / old_name
        new_dir = RESULTS / new_name
        metrics_equal = load_csv(old_dir / "run_metrics.csv") == load_csv(new_dir / "run_metrics.csv")
        analysis_equal = scientific_analysis(old_dir / "analysis_v4.json") == scientific_analysis(
            new_dir / "analysis_v4.json"
        )
        oracle_equal = load_json(old_dir / "oracle_front.json") == load_json(new_dir / "oracle_front.json")
        comparisons[label] = {
            "old_directory": old_name,
            "new_directory": new_name,
            "run_metrics_exactly_equal": metrics_equal,
            "analysis_scientific_fields_exactly_equal": analysis_equal,
            "oracle_front_exactly_equal": oracle_equal,
            "pass": metrics_equal and analysis_equal and oracle_equal,
        }

    report = {
        "purpose": "Frozen-seed regression check after adding a scale-aware relative constraint tolerance.",
        "constraint_relative_tolerance": 1e-12,
        "comparison_scope": "30 paired seeds for the 400, 800 and 1600 evaluation studies and the 800-evaluation ablation.",
        "comparisons": comparisons,
        "all_pass": all(item["pass"] for item in comparisons.values()),
        "interpretation": (
            "The numerical boundary correction changes the deterministic cycle-time sensitivity result, "
            "but does not change any archived stochastic metric, analysis statistic or oracle front."
        ),
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    if not report["all_pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

"""Deterministic verification of the analytical catalogue reduction.

This is a computational verification experiment, not physical validation.  It
checks the structural proposition against independent dense sampling of the
declared design box and against a payload-by-cycle-time interaction matrix.
"""
from __future__ import annotations

import copy
import csv
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "03_model"))
sys.path.insert(0, str(ROOT / "04_algorithm"))

from ball_screw_model import evaluate_design, load_assumptions, load_catalog
from optimizer import nondominated_front

NUMERICAL_FEASIBILITY_TOL = 1e-10


def numerically_feasible(result):
    return all(float(value) <= NUMERICAL_FEASIBILITY_TOL for value in result["violations"].values())


def normalized_feasible_result(result):
    result = dict(result)
    if numerically_feasible(result):
        result["violations"] = {}
        result["total_violation"] = 0.0
        result["feasible"] = True
    return result


def analytical_candidate(index, assumptions, catalog):
    item = catalog[index]
    stroke = float(assumptions["stroke_m"])
    dwell = float(assumptions["dwell_each_end_s"])
    available = (float(assumptions["cycle_time_limit_s"]) - 2.0 * dwell) / 2.0
    ta_lo, ta_hi = map(float, assumptions["acceleration_time_bounds_s"])
    rpm_limit = min(item.max_rpm, float(assumptions["dn_limit_mm_rpm"]) / item.dp_mm)
    velocity_limit = rpm_limit * item.lead_mm * 1e-3 / 60.0
    ta_star = min(ta_hi, available - stroke / velocity_limit)
    if ta_star < ta_lo:
        return None
    velocity = stroke / (available - ta_star)
    return evaluate_design(index, ta_star, velocity, catalog=catalog, assumptions=assumptions)


def is_contiguous(mask):
    true_indices = np.flatnonzero(mask)
    if len(true_indices) == 0:
        return True
    return bool(np.all(np.diff(true_indices) == 1))


def audit_case(name, assumptions, boundary_points, box_points):
    catalog = load_catalog()
    stroke = float(assumptions["stroke_m"])
    dwell = float(assumptions["dwell_each_end_s"])
    available = (float(assumptions["cycle_time_limit_s"]) - 2.0 * dwell) / 2.0
    ta_lo, ta_hi = map(float, assumptions["acceleration_time_bounds_s"])
    v_lo, v_hi = map(float, assumptions["velocity_bounds_m_s"])

    row_records = []
    exact_feasible = []
    grid_best = []
    for index, item in enumerate(catalog):
        candidate = analytical_candidate(index, assumptions, catalog)
        if candidate is not None and numerically_feasible(candidate):
            exact_feasible.append(normalized_feasible_result(candidate))

        boundary_ta = np.linspace(ta_lo, ta_hi, boundary_points)
        boundary_results = []
        for ta in boundary_ta:
            denominator = available - float(ta)
            if denominator <= 0:
                continue
            velocity = stroke / denominator
            if not (v_lo <= velocity <= v_hi):
                continue
            boundary_results.append(
                evaluate_design(index, float(ta), velocity, catalog=catalog, assumptions=assumptions)
            )
        deformation = np.asarray([x["deformation_um"] for x in boundary_results], dtype=float)
        boundary_monotone = bool(len(deformation) < 2 or np.all(np.diff(deformation) <= 1e-10))
        boundary_feasible = np.asarray([numerically_feasible(x) for x in boundary_results], dtype=bool)
        feasible_contiguous = is_contiguous(boundary_feasible)

        best = None
        ta_values = np.linspace(ta_lo, ta_hi, box_points)
        if candidate is not None:
            ta_values = np.unique(np.append(ta_values, float(candidate["accel_time_s"])))
        for ta in ta_values:
            denominator = available - float(ta)
            if denominator <= 0:
                continue
            required_velocity = max(v_lo, stroke / denominator)
            if required_velocity > v_hi:
                continue
            for velocity in np.linspace(required_velocity, v_hi, box_points):
                result = evaluate_design(
                    index, float(ta), float(velocity), catalog=catalog, assumptions=assumptions
                )
                if numerically_feasible(result) and (best is None or result["deformation_um"] < best["deformation_um"]):
                    best = normalized_feasible_result(result)
        if best is not None:
            grid_best.append(best)

        if candidate is not None and numerically_feasible(candidate):
            candidate_consistent = best is not None and candidate["deformation_um"] <= best["deformation_um"] + 1e-9
        else:
            candidate_consistent = best is None

        row_records.append({
            "case": name,
            "model": item.model,
            "boundary_monotone": boundary_monotone,
            "boundary_feasible_contiguous": feasible_contiguous,
            "analytical_candidate_feasible": bool(candidate is not None and numerically_feasible(candidate)),
            "box_grid_found_feasible": best is not None,
            "candidate_consistent_with_box_grid": candidate_consistent,
            "candidate_violation_keys": "" if candidate is None else ";".join(candidate["violations"].keys()),
            "candidate_max_normalized_violation": None if candidate is None or not candidate["violations"] else max(candidate["violations"].values()),
            "candidate_deformation_um": None if candidate is None else candidate["deformation_um"],
            "box_grid_best_deformation_um": None if best is None else best["deformation_um"],
        })

    exact_front = nondominated_front(exact_feasible)
    grid_front = nondominated_front(grid_best)
    exact_models = sorted(x["model"] for x in exact_front)
    grid_models = sorted(x["model"] for x in grid_front)
    summary = {
        "case": name,
        "catalog_rows": len(catalog),
        "boundary_points_per_row": boundary_points,
        "box_points_per_dimension": box_points,
        "constraint_grid_includes_analytical_candidate": True,
        "boundary_monotone_rows": sum(x["boundary_monotone"] for x in row_records),
        "contiguous_feasible_rows": sum(x["boundary_feasible_contiguous"] for x in row_records),
        "candidate_consistent_rows": sum(x["candidate_consistent_with_box_grid"] for x in row_records),
        "analytical_feasible_catalogues": len(exact_feasible),
        "box_grid_feasible_catalogues": len(grid_best),
        "analytical_pareto_models": exact_models,
        "box_grid_pareto_models": grid_models,
        "pareto_identity_match": exact_models == grid_models,
    }
    summary["passed"] = (
        summary["boundary_monotone_rows"] == len(catalog)
        and summary["contiguous_feasible_rows"] == len(catalog)
        and summary["candidate_consistent_rows"] == len(catalog)
        and summary["pareto_identity_match"]
    )
    return summary, row_records


def main():
    base = load_assumptions()
    summaries = []
    rows = []

    summary, details = audit_case("baseline", base, boundary_points=2001, box_points=121)
    summaries.append(summary)
    rows.extend(details)

    for payload_scale in (0.8, 1.0, 1.2):
        for cycle_time in (2.3, 2.5, 2.8):
            assumptions = copy.deepcopy(base)
            assumptions["external_translated_mass_scenarios_kg"] = [
                payload_scale * float(x) for x in base["external_translated_mass_scenarios_kg"]
            ]
            assumptions["cycle_time_limit_s"] = cycle_time
            name = f"payload_{payload_scale:.1f}_cycle_{cycle_time:.1f}"
            summary, details = audit_case(name, assumptions, boundary_points=501, box_points=61)
            summaries.append(summary)
            rows.extend(details)

    output_dir = ROOT / "06_results" / "structural_reduction_verification"
    output_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "evidence_class": "deterministic computational verification; not physical validation",
        "baseline": summaries[0],
        "interaction_matrix": summaries[1:],
        "all_cases_passed": all(x["passed"] for x in summaries),
    }
    (output_dir / "structural_reduction_verification.json").write_text(
        json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    with (output_dir / "structural_reduction_rows.csv").open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    if not payload["all_cases_passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

"""One-factor-at-a-time sensitivity of the analytical catalogue Pareto set."""
from __future__ import annotations

import copy
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "03_model"))
sys.path.insert(0, str(ROOT / "04_algorithm"))
from ball_screw_model import evaluate_design, load_assumptions, load_catalog
from optimizer import nondominated_front


def analytical_front(a):
    cat = load_catalog()
    stroke = float(a["stroke_m"])
    available = (float(a["cycle_time_limit_s"]) - 2.0 * float(a["dwell_each_end_s"])) / 2.0
    ta_lo, ta_hi = map(float, a["acceleration_time_bounds_s"])
    candidates = []
    for idx, item in enumerate(cat):
        rpm_limit = min(item.max_rpm, float(a["dn_limit_mm_rpm"]) / item.dp_mm)
        v_limit = rpm_limit * item.lead_mm * 1e-3 / 60.0
        ta_star = min(ta_hi, available - stroke / v_limit)
        if ta_star < ta_lo:
            continue
        velocity = stroke / (available - ta_star)
        r = evaluate_design(idx, ta_star, velocity, catalog=cat, assumptions=a)
        if r["feasible"]:
            candidates.append(r)
    return nondominated_front(candidates), candidates


def main():
    base = load_assumptions()
    cases = []
    for scale in [0.8, 1.0, 1.2]:
        a = copy.deepcopy(base)
        a["external_translated_mass_scenarios_kg"] = [scale * float(x) for x in base["external_translated_mass_scenarios_kg"]]
        cases.append(("payload_scale", scale, a))
    for stiffness in [250.0, 500.0, 1000.0]:
        a = copy.deepcopy(base); a["bearing_stiffness_N_um"] = stiffness
        cases.append(("bearing_stiffness_N_um", stiffness, a))
    for eta_floor in [0.80, 0.85, 0.90]:
        a = copy.deepcopy(base); a["efficiency_scenarios"] = [0.92, 0.90, eta_floor]
        cases.append(("worst_efficiency", eta_floor, a))
    for cycle in [2.3, 2.5, 2.8]:
        a = copy.deepcopy(base); a["cycle_time_limit_s"] = cycle
        cases.append(("cycle_time_limit_s", cycle, a))
    for peak, rms in [(4.0, 2.0), (5.0, 2.5), (6.0, 3.0)]:
        a = copy.deepcopy(base); a["motor_peak_torque_Nm"] = peak; a["motor_rms_torque_Nm"] = rms
        cases.append(("motor_limits_peak_rms_Nm", f"{peak}/{rms}", a))
    for length in [0.50, 0.65, 0.80]:
        a = copy.deepcopy(base); a["shaft_length_m"] = length
        cases.append(("shaft_length_m", length, a))
    for name, k_eff, beta in [("fixed-fixed", 0.5, 4.7300), ("fixed-supported", 0.699, 3.9266), ("pinned-pinned", 1.0, 3.1416)]:
        a = copy.deepcopy(base); a["support_condition"] = name
        a["effective_length_factor_buckling"] = k_eff; a["critical_speed_betaL"] = beta
        cases.append(("support_case", name, a))

    rows = []; details = []
    for factor, level, a in cases:
        front, feasible = analytical_front(a)
        rows.append({
            "factor": factor, "level": level, "feasible_catalog_count": len(feasible),
            "pareto_count": len(front), "pareto_models": ";".join(x["model"] for x in front),
            "min_mass_kg": min((x["hardware_mass_kg"] for x in front), default=""),
            "min_deformation_um": min((x["deformation_um"] for x in front), default="")
        })
        details.append({"factor": factor, "level": level, "front": front})
    out = ROOT / "06_results" / "sensitivity"
    out.mkdir(parents=True, exist_ok=True)
    with (out / "sensitivity_summary.csv").open("w", newline="", encoding="utf-8-sig") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
    (out / "sensitivity_details.json").write_text(json.dumps(details, indent=2, ensure_ascii=False, default=float), encoding="utf-8")
    print(json.dumps(rows, indent=2, ensure_ascii=False, default=float))


if __name__ == "__main__":
    main()

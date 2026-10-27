"""Evidence-bounded analytical model for catalog-constrained ball-screw selection.

The case parameters are explicit design assumptions. Catalog ratings are transcribed
from THK BTK-V technical data. The model is suitable for comparative computational
experiments, not a claim of physical validation for a specific machine.
"""
from __future__ import annotations

import csv
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Sequence

ROOT = Path(__file__).resolve().parent


@dataclass(frozen=True)
class CatalogItem:
    model: str
    d_mm: float
    lead_mm: float
    dp_mm: float
    dc_mm: float
    Ca_kN: float
    C0a_kN: float
    K_N_um: float
    nut_mass_kg: float
    shaft_mass_kg_m: float
    max_rpm: float


def load_catalog(path: Path = ROOT / "catalog_btkv.csv") -> List[CatalogItem]:
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    return [CatalogItem(
        model=r["model"], d_mm=float(r["d_mm"]), lead_mm=float(r["lead_mm"]),
        dp_mm=float(r["dp_mm"]), dc_mm=float(r["dc_mm"]),
        Ca_kN=float(r["Ca_kN"]), C0a_kN=float(r["C0a_kN"]),
        K_N_um=float(r["K_N_um"]), nut_mass_kg=float(r["nut_mass_kg"]),
        shaft_mass_kg_m=float(r["shaft_mass_kg_m"]), max_rpm=float(r["max_rpm"])
    ) for r in rows]


def load_assumptions(path: Path = ROOT / "assumptions.json") -> Dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def trapezoid_segments(stroke_m: float, velocity_m_s: float, accel_time_s: float):
    """Return durations, velocities and signed accelerations for one upward move.

    Distance equals v*(T - ta), hence cruise duration is stroke/v - ta.
    """
    cruise_time = stroke_m / velocity_m_s - accel_time_s
    if cruise_time < 0:
        return None
    accel = velocity_m_s / accel_time_s
    return [
        (accel_time_s, 0.5 * velocity_m_s, accel),
        (cruise_time, velocity_m_s, 0.0),
        (accel_time_s, 0.5 * velocity_m_s, -accel),
    ]


def evaluate_design(model_index: int, accel_time_s: float, velocity_m_s: float,
                    catalog: Sequence[CatalogItem] | None = None,
                    assumptions: Dict[str, object] | None = None) -> Dict[str, object]:
    catalog = list(catalog or load_catalog())
    a = assumptions or load_assumptions()
    item = catalog[int(model_index)]
    stroke = float(a["stroke_m"])
    segments = trapezoid_segments(stroke, velocity_m_s, accel_time_s)
    violations: Dict[str, float] = {}
    if segments is None:
        violations["kinematic"] = velocity_m_s * accel_time_s - stroke
        segments = [(accel_time_s, 0.5 * velocity_m_s, velocity_m_s / accel_time_s)]

    lead_m = item.lead_mm * 1e-3
    screw_radius_m = item.dc_mm * 5e-4
    shaft_mass = item.shaft_mass_kg_m * float(a["shaft_length_m"])
    polar_inertia = 0.5 * shaft_mass * screw_radius_m ** 2
    probs = [float(x) for x in a["scenario_probabilities"]]
    external_masses = [float(x) for x in a["external_translated_mass_scenarios_kg"]]
    translated_masses = [x + item.nut_mass_kg for x in external_masses]
    etas = [float(x) for x in a["efficiency_scenarios"]]
    g = float(a["gravity_m_s2"])

    peak_torque = 0.0
    scenario_rms_sq = []
    scenario_load_terms = []
    scenario_rev_terms = []
    peak_force = 0.0
    for mass, eta in zip(translated_masses, etas):
        torque_sq_time = 0.0
        total_motion_time = 0.0
        load_cube_rev = 0.0
        total_rev = 0.0
        # Up and down moves; signed gravity preserves realistic motor torque direction.
        for direction in (1.0, -1.0):
            for duration, mean_v, signed_acc in segments:
                acc_linear = direction * signed_acc
                force = mass * (g + acc_linear)
                omega_dot = (2.0 * math.pi / lead_m) * acc_linear
                drive_torque = force * lead_m / (2.0 * math.pi * eta) + polar_inertia * omega_dot
                peak_torque = max(peak_torque, abs(drive_torque))
                peak_force = max(peak_force, abs(force))
                torque_sq_time += drive_torque ** 2 * duration
                total_motion_time += duration
                rev = abs(mean_v / lead_m) * duration
                load_cube_rev += abs(force) ** 3 * rev
                total_rev += rev
        scenario_rms_sq.append(torque_sq_time / total_motion_time)
        scenario_load_terms.append(load_cube_rev)
        scenario_rev_terms.append(total_rev)

    expected_rms_torque = math.sqrt(sum(p * x for p, x in zip(probs, scenario_rms_sq)))
    equivalent_load = (sum(p * x for p, x in zip(probs, scenario_load_terms)) /
                       sum(p * x for p, x in zip(probs, scenario_rev_terms))) ** (1.0 / 3.0)
    # Mean rotational speed during moving periods; revolutions divided by time.
    move_time_one = stroke / velocity_m_s + accel_time_s
    mean_rpm = (stroke / lead_m) / move_time_one * 60.0
    life_h = 1e6 / (60.0 * mean_rpm) * ((item.Ca_kN * 1000.0) /
              (equivalent_load * float(a["load_factor_fw"]))) ** 3
    static_safety = item.C0a_kN * 1000.0 / peak_force
    max_rpm = velocity_m_s / lead_m * 60.0
    dn = item.dp_mm * max_rpm

    # Series stiffness: catalog nut, shaft segment, and explicitly assumed bearings.
    shaft_area = math.pi * (item.dc_mm * 1e-3) ** 2 / 4.0
    shaft_k_N_um = (float(a["youngs_modulus_Pa"]) * shaft_area /
                    float(a["shaft_length_m"])) / 1e6
    total_k = 1.0 / (1.0 / item.K_N_um + 1.0 / shaft_k_N_um +
                     1.0 / float(a["bearing_stiffness_N_um"]))
    deformation_um = peak_force / total_k

    # Fixed-supported shaft checks. The same root diameter used for axial
    # stiffness is used conservatively for Euler buckling and bending frequency.
    second_moment = math.pi * (item.dc_mm * 1e-3) ** 4 / 64.0
    effective_length = float(a["effective_length_factor_buckling"]) * float(a["shaft_length_m"])
    buckling_load_N = math.pi ** 2 * float(a["youngs_modulus_Pa"]) * second_moment / effective_length ** 2
    buckling_safety = buckling_load_N / peak_force
    mass_per_length = item.shaft_mass_kg_m
    betaL = float(a["critical_speed_betaL"])
    omega_critical = betaL ** 2 * math.sqrt(
        float(a["youngs_modulus_Pa"]) * second_moment /
        (mass_per_length * float(a["shaft_length_m"]) ** 4)
    )
    critical_speed_rpm = omega_critical * 60.0 / (2.0 * math.pi)
    allowable_critical_rpm = float(a["critical_speed_utilization_max"]) * critical_speed_rpm

    constraint_tolerance = float(a.get("constraint_relative_tolerance", 1e-12))

    def positive_excess(name: str, value: float, limit: float):
        tolerance = constraint_tolerance * max(abs(limit), 1.0)
        if value > limit + tolerance:
            violations[name] = (value - limit) / max(abs(limit), 1e-12)

    def positive_shortfall(name: str, value: float, minimum: float):
        tolerance = constraint_tolerance * max(abs(minimum), 1.0)
        if value < minimum - tolerance:
            violations[name] = (minimum - value) / max(abs(minimum), 1e-12)

    positive_excess("catalog_max_rpm", max_rpm, item.max_rpm)
    positive_excess("dn", dn, float(a["dn_limit_mm_rpm"]))
    positive_excess("peak_torque", peak_torque, float(a["motor_peak_torque_Nm"]))
    positive_excess("rms_torque", expected_rms_torque, float(a["motor_rms_torque_Nm"]))
    positive_excess("deformation", deformation_um, float(a["allowable_axial_deformation_um"]))
    positive_shortfall("life", life_h, float(a["operating_hours_target_h"]))
    positive_shortfall("static_safety", static_safety, float(a["static_safety_min"]))
    positive_shortfall("buckling_safety", buckling_safety, float(a["buckling_safety_min"]))
    positive_excess("critical_speed", max_rpm, allowable_critical_rpm)

    cycle_time = 2.0 * move_time_one + 2.0 * float(a["dwell_each_end_s"])
    positive_excess("cycle_time", cycle_time, float(a["cycle_time_limit_s"]))
    hardware_mass = item.nut_mass_kg + shaft_mass
    return {
        "model_index": int(model_index), "model": item.model,
        "accel_time_s": float(accel_time_s), "velocity_m_s": float(velocity_m_s),
        "objectives": [hardware_mass, deformation_um],
        "hardware_mass_kg": hardware_mass, "cycle_time_s": cycle_time,
        "expected_rms_torque_Nm": expected_rms_torque, "peak_torque_Nm": peak_torque,
        "equivalent_load_N": equivalent_load, "life_h": life_h,
        "static_safety": static_safety, "max_rpm": max_rpm, "dn_mm_rpm": dn,
        "total_stiffness_N_um": total_k, "deformation_um": deformation_um,
        "translated_masses_kg": translated_masses,
        "buckling_load_N": buckling_load_N, "buckling_safety": buckling_safety,
        "critical_speed_rpm": critical_speed_rpm,
        "allowable_critical_speed_rpm": allowable_critical_rpm,
        "violations": violations, "total_violation": float(sum(violations.values())),
        "feasible": not violations
    }

import math
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "03_model"))
from ball_screw_model import evaluate_design, load_assumptions, load_catalog, trapezoid_segments


class BallScrewModelTests(unittest.TestCase):
    def test_catalog_has_traceable_19_models(self):
        cat = load_catalog()
        self.assertEqual(len(cat), 19)
        self.assertEqual(cat[0].model, "BTK1006V-2.6")
        self.assertEqual(cat[-1].model, "BTK5016V-5.3")

    def test_trapezoid_distance_is_exact(self):
        segs = trapezoid_segments(0.4, 0.8, 0.2)
        distance = sum(duration * mean_v for duration, mean_v, _ in segs)
        self.assertAlmostEqual(distance, 0.4, places=12)

    def test_speed_to_rpm_dimensional_conversion(self):
        result = evaluate_design(7, 0.2, 0.5)  # 10 mm lead
        self.assertAlmostEqual(result["max_rpm"], 3000.0, places=9)

    def test_mass_uses_catalog_nut_plus_shaft(self):
        result = evaluate_design(0, 0.2, 0.3)
        self.assertAlmostEqual(result["hardware_mass_kg"], 0.12 + 0.48 * 0.65)

    def test_selected_nut_mass_is_in_translated_mass(self):
        result = evaluate_design(9, 0.2, 0.5)
        self.assertAlmostEqual(result["translated_masses_kg"][0], 80.0 + 1.83)

    def test_fixed_supported_shaft_checks_are_positive(self):
        result = evaluate_design(9, 0.2, 0.5)
        self.assertGreater(result["buckling_safety"], 0.0)
        self.assertGreater(result["critical_speed_rpm"], 0.0)

    def test_higher_velocity_shortens_cycle_at_fixed_acceleration_time(self):
        slow = evaluate_design(9, 0.2, 0.4)
        fast = evaluate_design(9, 0.2, 0.8)
        self.assertLess(fast["cycle_time_s"], slow["cycle_time_s"])

    def test_objectives_are_mass_and_deformation(self):
        result = evaluate_design(9, 0.2, 0.5)
        self.assertEqual(result["objectives"], [result["hardware_mass_kg"], result["deformation_um"]])

    def test_constraint_violation_is_nonnegative(self):
        result = evaluate_design(0, 0.08, 1.2)
        self.assertGreaterEqual(result["total_violation"], 0.0)
        self.assertTrue(all(v >= 0 for v in result["violations"].values()))

    def test_roundoff_at_catalog_speed_limit_is_not_infeasible(self):
        assumptions = load_assumptions()
        catalog = load_catalog()
        assumptions["cycle_time_limit_s"] = 2.3
        index = next(i for i, item in enumerate(catalog) if item.model == "BTK2510V-5.3")
        item = catalog[index]
        available = (assumptions["cycle_time_limit_s"] - 2.0 * assumptions["dwell_each_end_s"]) / 2.0
        velocity_limit = item.max_rpm * item.lead_mm * 1e-3 / 60.0
        accel_time = available - assumptions["stroke_m"] / velocity_limit
        result = evaluate_design(index, accel_time, velocity_limit, catalog=catalog, assumptions=assumptions)
        self.assertTrue(result["feasible"])
        self.assertNotIn("catalog_max_rpm", result["violations"])


if __name__ == "__main__":
    unittest.main(verbosity=2)

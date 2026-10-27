import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "04_algorithm"))
sys.path.insert(0, str(ROOT / "05_experiments"))
from optimizer import dominates, hypervolume_2d, run_optimizer
from run_study import make_oracle


def item(obj, violation=0.0):
    return {"objectives": obj, "total_violation": violation}


class OptimizerTests(unittest.TestCase):
    def test_constraint_domination(self):
        self.assertTrue(dominates(item([9, 9], 0), item([1, 1], 0.1)))
        self.assertTrue(dominates(item([2, 3], 0), item([3, 3], 0)))
        self.assertFalse(dominates(item([2, 4], 0), item([3, 3], 0)))

    def test_hypervolume_simple_rectangle(self):
        self.assertAlmostEqual(hypervolume_2d([[0.5, 0.5]], (1, 1)), 0.25)

    def test_budget_is_exact_and_catalog_indices_valid(self):
        result = run_optimizer("ctade", seed=11, budget=80, pop_size=20)
        self.assertEqual(result["budget"], 80)
        self.assertTrue(all(0 <= x["model_index"] < 19 for x in result["front"]))

    def test_nsga2_baseline_budget_is_exact(self):
        result = run_optimizer("nsga2_mixed", seed=7, budget=80, pop_size=20)
        self.assertEqual(result["budget"], 80)

    def test_analytical_catalog_oracle_has_four_tradeoff_models(self):
        front, feasible_catalogs = make_oracle()
        self.assertEqual(len(front), 4)
        self.assertGreaterEqual(feasible_catalogs, len(front))
        self.assertEqual({x["model"] for x in front}, {
            "BTK2510V-5.3", "BTK3210V-2.6", "BTK3210V-5.3", "BTK3610V-5.3"
        })


if __name__ == "__main__":
    unittest.main(verbosity=2)

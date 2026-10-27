"""Run oracle construction, equal-budget pilots/full experiments, and statistics."""
from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "03_model"))
sys.path.insert(0, str(ROOT / "04_algorithm"))
from ball_screw_model import evaluate_design, load_assumptions, load_catalog
from optimizer import hypervolume_2d, igd, nondominated_front, normalize_points, run_optimizer


def make_oracle():
    """Analytical catalogue oracle for this monotone three-variable case.

    For a fixed catalogue item, mass is constant and deformation increases with
    peak acceleration. On the active cycle-time boundary, acceleration is
    s/[ta*(A-ta)], where A is the allowable one-way move time. Since ta < A/2
    throughout the declared range, acceleration decreases monotonically with ta.
    The exact catalogue optimum is therefore the largest ta permitted by the
    acceleration bound and the effective rpm/DN speed limit.
    """
    a = load_assumptions(); cat = load_catalog()
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
        r = evaluate_design(idx, ta_star, velocity)
        if r["feasible"]:
            candidates.append(r)
    return nondominated_front(candidates), len(candidates)


def percentile(values, q):
    return float(np.percentile(np.asarray(values, dtype=float), q))


def sign_flip_pvalue(differences, seed=20260830, n_perm=100000):
    d = np.asarray(differences, dtype=float)
    observed = abs(float(np.mean(d)))
    if not np.any(d):
        return 1.0
    rng = np.random.default_rng(seed)
    extreme = 0
    batch = 5000
    done = 0
    while done < n_perm:
        size = min(batch, n_perm - done)
        signs = rng.choice(np.array([-1.0, 1.0]), size=(size, len(d)))
        extreme += int(np.sum(np.abs(np.mean(signs * d, axis=1)) >= observed))
        done += size
    return (extreme + 1.0) / (n_perm + 1.0)


def a12(a, b):
    wins = ties = 0
    for x in a:
        for y in b:
            wins += x > y
            ties += x == y
    return (wins + 0.5 * ties) / (len(a) * len(b))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seeds", type=int, default=10)
    parser.add_argument("--budget", type=int, default=800)
    parser.add_argument("--population", type=int, default=40)
    parser.add_argument("--label", default="pilot")
    parser.add_argument("--methods", default="ctade,index_de,random_catalog_de")
    args = parser.parse_args()
    outdir = ROOT / "06_results" / args.label
    outdir.mkdir(parents=True, exist_ok=True)

    oracle, feasible_catalog_count = make_oracle()
    oracle_obj = np.asarray([r["objectives"] for r in oracle], dtype=float)
    lower = oracle_obj.min(axis=0)
    upper = oracle_obj.max(axis=0)
    oracle_norm = normalize_points(oracle_obj, lower, upper)
    oracle_hv = hypervolume_2d(oracle_norm)
    (outdir / "oracle_front.json").write_text(json.dumps({
        "oracle_type": "analytical_per_catalog_monotonic_optimum",
        "catalog_models": 19,
        "feasible_catalog_count": feasible_catalog_count,
        "front": oracle
    }, indent=2, ensure_ascii=False, default=float), encoding="utf-8")

    methods = [x.strip() for x in args.methods.split(",") if x.strip()]
    rows = []
    raw_runs = []
    for seed in range(1, args.seeds + 1):
        for method in methods:
            result = run_optimizer(method, seed=seed, budget=args.budget, pop_size=args.population)
            points = [e["objectives"] for e in result["front"]]
            norm = normalize_points(points, lower, upper) if points else np.empty((0, 2))
            hv = hypervolume_2d(norm)
            distance = igd(oracle_norm, norm)
            models = sorted(set(e["model"] for e in result["front"]))
            rows.append({
                "method": method, "seed": seed, "budget": args.budget,
                "hypervolume": hv, "relative_hypervolume": hv / oracle_hv if oracle_hv else 0.0,
                "igd": distance, "first_feasible_evaluation": result["first_feasible_evaluation"],
                "feasible_population_fraction": result["feasible_population_fraction"],
                "front_size": len(result["front"]), "front_models": ";".join(models)
            })
            result["hypervolume"] = hv
            result["igd"] = distance
            raw_runs.append(result)
    with (outdir / "run_metrics.csv").open("w", newline="", encoding="utf-8-sig") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0]))
        writer.writeheader(); writer.writerows(rows)
    (outdir / "runs.json").write_text(json.dumps(raw_runs, indent=2, ensure_ascii=False, default=float), encoding="utf-8")

    summary = {"label": args.label, "seeds": args.seeds, "budget": args.budget,
               "population": args.population, "oracle_hypervolume": oracle_hv,
               "oracle_front_size": len(oracle), "methods": {}, "comparisons": {}}
    by_method = {m: [r for r in rows if r["method"] == m] for m in methods}
    for method, data in by_method.items():
        summary["methods"][method] = {}
        for metric in ["relative_hypervolume", "igd", "first_feasible_evaluation", "feasible_population_fraction"]:
            vals = [float(r[metric]) for r in data if r[metric] is not None and math.isfinite(float(r[metric]))]
            summary["methods"][method][metric] = {
                "median": statistics.median(vals), "q1": percentile(vals, 25),
                "q3": percentile(vals, 75), "mean": statistics.mean(vals),
                "std": statistics.stdev(vals) if len(vals) > 1 else 0.0
            }
    for baseline in [m for m in methods if m != "ctade"]:
        c = [float(r["relative_hypervolume"]) for r in by_method["ctade"]]
        b = [float(r["relative_hypervolume"]) for r in by_method[baseline]]
        summary["comparisons"][f"ctade_vs_{baseline}"] = {
            "paired_mean_difference_relative_hv": statistics.mean([x-y for x, y in zip(c, b)]),
            "sign_flip_p_two_sided": sign_flip_pvalue([x-y for x, y in zip(c, b)]),
            "vargha_delaney_A12_higher_is_better": a12(c, b)
        }
    (outdir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

"""Equal-budget constrained multiobjective optimizers for the study.

CTADE differs only in the catalog-variable operator; continuous variation,
constraint domination, environmental selection, population size and evaluation
budget are identical across comparisons.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Sequence, Tuple

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "03_model"))
from ball_screw_model import evaluate_design, load_catalog, load_assumptions


def dominates(a: Dict[str, object], b: Dict[str, object]) -> bool:
    va, vb = float(a["total_violation"]), float(b["total_violation"])
    if va == 0.0 and vb > 0.0:
        return True
    if va > 0.0 and vb == 0.0:
        return False
    if va > 0.0 or vb > 0.0:
        return va < vb
    fa = np.asarray(a["objectives"], dtype=float)
    fb = np.asarray(b["objectives"], dtype=float)
    return bool(np.all(fa <= fb) and np.any(fa < fb))


def nondominated_front(items: Sequence[Dict[str, object]]) -> List[Dict[str, object]]:
    return [x for i, x in enumerate(items)
            if not any(j != i and dominates(y, x) for j, y in enumerate(items))]


def fast_nondominated_sort(items: Sequence[Dict[str, object]]) -> List[List[int]]:
    n = len(items)
    dominated = [[] for _ in range(n)]
    count = [0] * n
    fronts = [[]]
    for p in range(n):
        for q in range(n):
            if p == q:
                continue
            if dominates(items[p], items[q]):
                dominated[p].append(q)
            elif dominates(items[q], items[p]):
                count[p] += 1
        if count[p] == 0:
            fronts[0].append(p)
    k = 0
    while k < len(fronts) and fronts[k]:
        nxt = []
        for p in fronts[k]:
            for q in dominated[p]:
                count[q] -= 1
                if count[q] == 0:
                    nxt.append(q)
        k += 1
        if nxt:
            fronts.append(nxt)
    return fronts


def crowding_distance(items: Sequence[Dict[str, object]], indices: Sequence[int]) -> Dict[int, float]:
    if not indices:
        return {}
    dist = {i: 0.0 for i in indices}
    # Constraint violation acts as the scalar coordinate for infeasible fronts.
    if any(float(items[i]["total_violation"]) > 0 for i in indices):
        values = {i: float(items[i]["total_violation"]) for i in indices}
        ordered = sorted(indices, key=values.get)
        dist[ordered[0]] = dist[ordered[-1]] = math.inf
        span = values[ordered[-1]] - values[ordered[0]]
        if span > 0:
            for pos in range(1, len(ordered) - 1):
                dist[ordered[pos]] += (values[ordered[pos + 1]] - values[ordered[pos - 1]]) / span
        return dist
    for obj in range(2):
        ordered = sorted(indices, key=lambda i: float(items[i]["objectives"][obj]))
        dist[ordered[0]] = dist[ordered[-1]] = math.inf
        lo = float(items[ordered[0]]["objectives"][obj])
        hi = float(items[ordered[-1]]["objectives"][obj])
        if hi > lo:
            for pos in range(1, len(ordered) - 1):
                prev_v = float(items[ordered[pos - 1]]["objectives"][obj])
                next_v = float(items[ordered[pos + 1]]["objectives"][obj])
                dist[ordered[pos]] += (next_v - prev_v) / (hi - lo)
    return dist


def environmental_select(vectors: np.ndarray, evaluations: List[Dict[str, object]], n_keep: int):
    keep = []
    for front in fast_nondominated_sort(evaluations):
        if len(keep) + len(front) <= n_keep:
            keep.extend(front)
        else:
            cd = crowding_distance(evaluations, front)
            keep.extend(sorted(front, key=lambda i: cd[i], reverse=True)[:n_keep - len(keep)])
            break
    return vectors[keep].copy(), [evaluations[i] for i in keep]


def catalog_features() -> np.ndarray:
    cat = load_catalog()
    raw = np.array([[c.d_mm, c.lead_mm, c.Ca_kN, c.C0a_kN, c.K_N_um,
                     c.nut_mass_kg, c.shaft_mass_kg_m, c.max_rpm] for c in cat], dtype=float)
    lo, hi = raw.min(axis=0), raw.max(axis=0)
    return (raw - lo) / np.where(hi > lo, hi - lo, 1.0)


def decode_and_evaluate(x: Sequence[float]) -> Dict[str, object]:
    a = load_assumptions()
    ncat = len(load_catalog())
    idx = int(np.clip(np.rint(x[0]), 0, ncat - 1))
    ta = float(np.clip(x[1], *a["acceleration_time_bounds_s"]))
    vel = float(np.clip(x[2], *a["velocity_bounds_m_s"]))
    return evaluate_design(idx, ta, vel)


def run_optimizer(method: str, seed: int, budget: int = 2000, pop_size: int = 40,
                  F: float = 0.6, CR: float = 0.9) -> Dict[str, object]:
    if method not in {"ctade", "ctade_feature_only", "ctade_neighbor_only",
                      "index_de", "random_catalog_de", "nsga2_mixed"}:
        raise ValueError(method)
    if budget < pop_size:
        raise ValueError("budget must be at least population size")
    rng = np.random.default_rng(seed)
    a = load_assumptions()
    cat = load_catalog()
    ncat = len(cat)
    bounds = np.array([[0.0, ncat - 1.0], a["acceleration_time_bounds_s"],
                       a["velocity_bounds_m_s"]], dtype=float)
    if method == "nsga2_mixed":
        return _run_nsga2_mixed(seed, budget, pop_size, bounds)
    pop = rng.uniform(bounds[:, 0], bounds[:, 1], size=(pop_size, 3))
    pop[:, 0] = rng.integers(0, ncat, size=pop_size)
    evals = [decode_and_evaluate(x) for x in pop]
    n_eval = pop_size
    first_feasible = next((i + 1 for i, e in enumerate(evals) if e["feasible"]), None)
    features = catalog_features()
    attempts = np.ones(ncat, dtype=float) * 2.0
    successes = np.ones(ncat, dtype=float)
    for e in evals:
        idx = int(e["model_index"]); attempts[idx] += 1.0; successes[idx] += float(e["feasible"])
    history = []
    while n_eval < budget:
        feasible_ratio = float(np.mean([e["feasible"] for e in evals]))
        trials = []
        batch = min(pop_size, budget - n_eval)
        for i in range(batch):
            choices = [j for j in range(pop_size) if j != i]
            r1, r2, r3 = rng.choice(choices, 3, replace=False)
            mutant = pop[r1] + F * (pop[r2] - pop[r3])
            mask = rng.random(3) < CR
            mask[rng.integers(0, 3)] = True
            trial = np.where(mask, mutant, pop[i]).astype(float)
            if method == "random_catalog_de":
                trial[0] = rng.integers(0, ncat) if rng.random() < 0.5 else pop[i, 0]
            elif method.startswith("ctade"):
                if method == "ctade_feature_only":
                    p_feasibility = 0.0
                elif method == "ctade_neighbor_only":
                    p_feasibility = 1.0
                else:
                    p_feasibility = 0.20 + 0.65 * (1.0 - feasible_ratio)
                if rng.random() < p_feasibility:
                    current = int(np.rint(pop[i, 0]))
                    distances = np.linalg.norm(features - features[current], axis=1)
                    neighbors = np.argsort(distances)[1:7]
                    score = (successes[neighbors] / attempts[neighbors]) + 0.05
                    score = score / score.sum()
                    trial[0] = int(rng.choice(neighbors, p=score))
                else:
                    fa, fb, fc = features[int(pop[r1, 0])], features[int(pop[r2, 0])], features[int(pop[r3, 0])]
                    desired = fa + F * (fb - fc)
                    trial[0] = int(np.argmin(np.linalg.norm(features - desired, axis=1)))
            trial = np.clip(trial, bounds[:, 0], bounds[:, 1])
            trial[0] = np.rint(trial[0])
            trials.append(trial)
        trial_arr = np.asarray(trials)
        trial_evals = [decode_and_evaluate(x) for x in trial_arr]
        for offset, e in enumerate(trial_evals):
            idx = int(e["model_index"]); attempts[idx] += 1.0; successes[idx] += float(e["feasible"])
            if e["feasible"] and first_feasible is None:
                first_feasible = n_eval + offset + 1
        n_eval += batch
        pop, evals = environmental_select(np.vstack([pop, trial_arr]), evals + trial_evals, pop_size)
        front = [e for e in nondominated_front(evals) if e["feasible"]]
        history.append({"evaluations": n_eval, "feasible_ratio": feasible_ratio,
                        "front_size": len(front),
                        "front_objectives": [e["objectives"] for e in front]})
    front = [e for e in nondominated_front(evals) if e["feasible"]]
    return {"method": method, "seed": seed, "budget": budget,
            "first_feasible_evaluation": first_feasible,
            "feasible_population_fraction": float(np.mean([e["feasible"] for e in evals])),
            "front": front, "history": history}


def _rank_and_crowding(evals):
    ranks = np.empty(len(evals), dtype=int); crowd = np.zeros(len(evals), dtype=float)
    for rank, front in enumerate(fast_nondominated_sort(evals)):
        cd = crowding_distance(evals, front)
        for i in front: ranks[i] = rank; crowd[i] = cd[i]
    return ranks, crowd


def _run_nsga2_mixed(seed, budget, pop_size, bounds):
    """Standard NSGA-II baseline with SBX, polynomial mutation and random categorical mutation."""
    rng = np.random.default_rng(seed); ncat = int(bounds[0,1] + 1)
    pop = rng.uniform(bounds[:,0], bounds[:,1], size=(pop_size,3)); pop[:,0]=rng.integers(0,ncat,size=pop_size)
    evals=[decode_and_evaluate(x) for x in pop]; n_eval=pop_size
    first_feasible=next((i+1 for i,e in enumerate(evals) if e["feasible"]),None); history=[]
    eta_c=15.0; eta_m=20.0
    while n_eval < budget:
        ranks,crowd=_rank_and_crowding(evals)
        def tournament():
            i,j=rng.integers(0,pop_size,size=2)
            if ranks[i] < ranks[j] or (ranks[i]==ranks[j] and crowd[i]>crowd[j]): return i
            return j
        children=[]; batch=min(pop_size,budget-n_eval)
        while len(children)<batch:
            p1,p2=pop[tournament()].copy(),pop[tournament()].copy(); c=p1.copy()
            c[0]=p1[0] if rng.random()<0.5 else p2[0]
            if rng.random()<1/3: c[0]=rng.integers(0,ncat)
            for k in (1,2):
                x1,x2=p1[k],p2[k]; lo,hi=bounds[k]
                if rng.random()<=0.9 and abs(x1-x2)>1e-14:
                    if x1>x2: x1,x2=x2,x1
                    u=rng.random(); beta=1+2*(x1-lo)/(x2-x1); alpha=2-beta**(-(eta_c+1))
                    betaq=(u*alpha)**(1/(eta_c+1)) if u<=1/alpha else (1/(2-u*alpha))**(1/(eta_c+1))
                    child=0.5*((x1+x2)-betaq*(x2-x1))
                    c[k]=child if rng.random()<0.5 else x1+x2-child
                if rng.random()<1/3:
                    y=float(np.clip(c[k],lo,hi)); delta1=(y-lo)/(hi-lo); delta2=(hi-y)/(hi-lo); u=rng.random(); mut_pow=1/(eta_m+1)
                    if u<0.5:
                        xy=1-delta1; val=2*u+(1-2*u)*(xy**(eta_m+1)); dq=val**mut_pow-1
                    else:
                        xy=1-delta2; val=2*(1-u)+2*(u-0.5)*(xy**(eta_m+1)); dq=1-val**mut_pow
                    c[k]=y+dq*(hi-lo)
                c[k]=np.clip(c[k],lo,hi)
            c[0]=np.rint(np.clip(c[0],0,ncat-1)); children.append(c)
        carr=np.asarray(children); ce=[decode_and_evaluate(x) for x in carr]
        for off,e in enumerate(ce):
            if e["feasible"] and first_feasible is None: first_feasible=n_eval+off+1
        n_eval+=len(ce); pop,evals=environmental_select(np.vstack([pop,carr]),evals+ce,pop_size)
        front=[e for e in nondominated_front(evals) if e["feasible"]]
        history.append({"evaluations":n_eval,"feasible_ratio":float(np.mean([e["feasible"] for e in evals])),
                        "front_size":len(front),"front_objectives":[e["objectives"] for e in front]})
    front=[e for e in nondominated_front(evals) if e["feasible"]]
    return {"method":"nsga2_mixed","seed":seed,"budget":budget,
            "first_feasible_evaluation":first_feasible,
            "feasible_population_fraction":float(np.mean([e["feasible"] for e in evals])),
            "front":front,"history":history}


def normalize_points(points: Sequence[Sequence[float]], lower: Sequence[float], upper: Sequence[float]):
    p = np.asarray(points, dtype=float)
    lo, hi = np.asarray(lower, dtype=float), np.asarray(upper, dtype=float)
    return (p - lo) / np.where(hi > lo, hi - lo, 1.0)


def hypervolume_2d(points: Sequence[Sequence[float]], reference=(1.1, 1.1)) -> float:
    if len(points) == 0:
        return 0.0
    pts = np.asarray(points, dtype=float)
    # remove points outside reference and retain only nondominated numeric points
    pts = pts[np.all(pts < np.asarray(reference), axis=1)]
    if len(pts) == 0:
        return 0.0
    nd = []
    for i, p in enumerate(pts):
        if not any(np.all(q <= p) and np.any(q < p) for j, q in enumerate(pts) if j != i):
            nd.append(p)
    nd = sorted(nd, key=lambda x: x[0])
    hv = 0.0
    for i, p in enumerate(nd):
        next_x = reference[0] if i == len(nd) - 1 else nd[i + 1][0]
        hv += max(0.0, next_x - p[0]) * max(0.0, reference[1] - p[1])
    return float(hv)


def igd(reference_points: Sequence[Sequence[float]], approximation: Sequence[Sequence[float]]) -> float:
    if len(approximation) == 0:
        return math.inf
    ref = np.asarray(reference_points, dtype=float)
    app = np.asarray(approximation, dtype=float)
    return float(np.mean([np.min(np.linalg.norm(app - p, axis=1)) for p in ref]))

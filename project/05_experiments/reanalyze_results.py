"""Publication-oriented paired analysis of completed raw run metrics."""
from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
from pathlib import Path

import numpy as np

ROOT=Path(__file__).resolve().parents[1]


def sign_flip(d, seed=20260830, n=200000):
    d=np.asarray(d,float); obs=abs(d.mean()); rng=np.random.default_rng(seed); ext=0
    for start in range(0,n,5000):
        k=min(5000,n-start); s=rng.choice([-1.0,1.0],size=(k,len(d))); ext+=int(np.sum(np.abs(np.mean(s*d,axis=1))>=obs))
    return (ext+1)/(n+1)


def bootstrap_ci(d, seed=20260830, n=50000):
    d=np.asarray(d,float); rng=np.random.default_rng(seed); means=[]
    for start in range(0,n,5000):
        k=min(5000,n-start); idx=rng.integers(0,len(d),size=(k,len(d))); means.extend(np.mean(d[idx],axis=1))
    return [float(x) for x in np.percentile(means,[2.5,97.5])]


def holm(pvals):
    order=sorted(range(len(pvals)),key=lambda i:pvals[i]); adjusted=[0.0]*len(pvals); running=0.0; m=len(pvals)
    for rank,i in enumerate(order):
        running=max(running,min(1.0,(m-rank)*pvals[i])); adjusted[i]=running
    return adjusted


def main():
    ap=argparse.ArgumentParser(); ap.add_argument("directory"); args=ap.parse_args()
    path=ROOT/"06_results"/args.directory; rows=list(csv.DictReader((path/"run_metrics.csv").open(encoding="utf-8-sig")))
    budget=int(rows[0]["budget"]); methods=sorted(set(r["method"] for r in rows),key=lambda m:(m!="ctade",m))
    by={m:sorted([r for r in rows if r["method"]==m],key=lambda r:int(r["seed"])) for m in methods}
    out={"directory":args.directory,"budget":budget,"seeds":len(by[methods[0]]),"primary_metric":"relative_hypervolume","methods":{},"paired_comparisons":{}}
    for m,rr in by.items():
        hv=np.array([float(x["relative_hypervolume"]) for x in rr]); first=[]; failed=0
        for x in rr:
            raw=x["first_feasible_evaluation"].strip()
            if raw=="": failed+=1; first.append(budget+1)
            else: first.append(float(raw))
        out["methods"][m]={"relative_hypervolume_median":float(np.median(hv)),"relative_hypervolume_q1":float(np.percentile(hv,25)),"relative_hypervolume_q3":float(np.percentile(hv,75)),
            "first_feasible_censored_median":float(np.median(first)),"no_feasible_solution_rate":failed/len(rr)}
    names=[]; p=[]
    for m in methods:
        if m=="ctade":continue
        c=np.array([float(x["relative_hypervolume"]) for x in by["ctade"]]); b=np.array([float(x["relative_hypervolume"]) for x in by[m]]); d=c-b
        name=f"ctade_vs_{m}"; names.append(name); pv=sign_flip(d);p.append(pv)
        out["paired_comparisons"][name]={"mean_difference":float(d.mean()),"median_difference":float(np.median(d)),"bootstrap_95_ci_mean_difference":bootstrap_ci(d),
            "sign_flip_p_two_sided":pv,"paired_superiority_probability":float((np.sum(d>0)+0.5*np.sum(d==0))/len(d))}
    adj=holm(p)
    for name,val in zip(names,adj):out["paired_comparisons"][name]["holm_adjusted_p_across_reported_baselines"]=val
    (path/"analysis_v4.json").write_text(json.dumps(out,indent=2),encoding="utf-8"); print(json.dumps(out,indent=2))


if __name__=="__main__":main()

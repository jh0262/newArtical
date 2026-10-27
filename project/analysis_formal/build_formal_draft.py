"""Assemble a result-bounded revision; preserve the pre-experiment draft."""
from pathlib import Path
import csv,json
ROOT=Path(__file__).resolve().parents[1]; OUT=Path(__file__).resolve().parent
NAMES=['MODE-CD-G','MODE-EAR-G','MODE-CD-S','MODE-EAR-S','MV-NSGA-II','MV-SPEA2','CAT-QMC']; CYCLES=[2.5,3.,3.5]
def rows(name): return list(csv.DictReader((OUT/name).open(encoding='utf-8-sig')))
def lookup(data,**kw): return next(r for r in data if all(str(r[k])==str(v) for k,v in kw.items()))
def main():
    src=(ROOT/'manuscript/manuscript_en_draft.md').read_text(encoding='utf-8')
    summary=rows('summary.csv'); paired=rows('paired_comparisons.csv'); pool=rows('saved_front_truncation_diagnostic.csv'); eng=rows('engineering_summary.csv')
    assert json.loads((OUT/'analysis_audit.json').read_text())['runs']==420
    hvtable='|Method|2.5 s|3.0 s|3.5 s|\n|---|---:|---:|---:|\n'
    for n in NAMES:
        vals=[float(lookup(summary,method=n,cycle_limit_s=c)['HV_median']) for c in CYCLES]
        hvtable+='|'+n+'|'+ '|'.join(f'{v:.6f}' for v in vals)+'|\n'
    pairtable='|Cycle ceiling|Mean paired HV difference|95% interval|Wins/losses|Holm p|\n|---|---:|---|---:|---:|\n'
    for c in CYCLES:
        r=lookup(paired,cycle_limit_s=c,comparator='MODE-CD-G')
        pairtable+=f"|{c:.1f} s|{float(r['mean_difference']):+.6f}|[{float(r['ci95_mean_low']):+.6f}, {float(r['ci95_mean_high']):+.6f}]|{r['wins']}/{r['losses']}|{float(r['p_holm_6']):.3f}|\n"
    pooltable='|Cycle ceiling|Nondominated pool size|One-pass CD HV|Bounded-ear HV|Iterative CD HV|\n|---|---:|---:|---:|---:|\n'
    poolrows=[]
    for c in CYCLES:
        rr=[next(r for r in pool if float(r['cycle_limit_s'])==c and r['selector']==n) for n in ['one_pass_CD','bounded_ear','iterative_CD']]
        vals=[float(r['HV']) for r in rr]
        line=f"|{c:.1f} s|{int(rr[0]['pool_size']):,}|"+'|'.join(f'{v:.6f}' for v in vals)+'|\n'
        pooltable+=line; poolrows.append(line)
    engtable='|Cycle ceiling|Baseline MODE median cycle|Combined MODE median cycle|Attainment, baseline/combined|\n|---|---:|---:|---:|\n'
    for c in CYCLES:
        rr=[lookup(eng,cycle_limit_s=c,method=n,residual_threshold_um=.1) for n in ['MODE-CD-G','MODE-EAR-S']]
        engtable+=f"|{c:.1f} s|{float(rr[0]['conditional_median_cycle_s']):.6f} s|{float(rr[1]['conditional_median_cycle_s']):.6f} s|{rr[0]['attained_runs']}/20; {rr[1]['attained_runs']}/20|\n"
    abstract='''## Abstract

Catalogue selection and motion planning interact through the stiffness, inertia and operating limits of ball-screw actuators. A mixed categorical–continuous formulation is developed to minimize travel time and the largest residual-vibration envelope across nine assumed operating scenarios. Exact segment propagation and an anti-periodic initial condition evaluate repeated seven-segment motion without resetting the vibration state. Coverage-bounded triangle-area selection and a catalogue-stratified guide archive are examined in a factorial differential-evolution framework. The completed study comprises 420 runs of seven methods at three cycle ceilings, with 20 paired seeds and 32,064 design evaluations per run. Independent integration verifies the response evaluator, and all 26,880 final designs reproduce their saved objectives and constraint violations. The combined method does not significantly outperform the baseline MODE at any cycle ceiling after Holm adjustment; neither mechanism nor their interaction has a significant factorial effect. A separate, post-hoc compression diagnostic improves finite-pool hypervolume over one-pass crowding distance but yields results close to iterative crowding-distance pruning. The study therefore distinguishes verifiable archive compression from unproven search improvement. Engineering outputs remain predictions of an assumed reduced-order model, without experimental or finite-element validation.

'''
    intro=src[src.index('**Keywords:**'):src.index('## 4. Numerical study design')]
    intro=intro.replace('A positive algorithmic claim remains conditional on the planned repeated experiments and the outstanding closest-work review.', 'The completed experiments test this claim; the closest-work review still requires additional full-text comparison.')
    intro=intro.replace('A two-by-two ablation of truncation and archive structure is required to separate these effects.', 'A two-by-two ablation of truncation and archive structure is used below to separate these effects.')
    methods='''## 4. Completed numerical study and analysis

Verification and optimizer comparison were conducted separately. Independent SciPy DOP853 integration checked the trajectory and forced differential equation. The same frozen MATLAB implementation then evaluated seven methods: the four combinations of ear selection and archive structure, mixed-variable NSGA-II and SPEA2 reference implementations [4,5], and catalogue-stratified scrambled Sobol sampling. The two GA references explicitly adapt category handling; they are not represented as unmodified third-party implementations.

At each cycle ceiling of 2.5, 3.0 and 3.5 s, 20 paired seeds (93101–93120) were run with population size 64 and 500 offspring generations. Initialization was included in the budget, giving 32,064 design evaluations per run and 13,466,880 in total. One evaluation includes all nine scenarios and all constraints. Initial populations were generated identically across methods; the initial HV agreed exactly for every paired seed. The formal batch completed in 374.5 s on the current host, within the authorized 1,800 s cap. No method was rerun to improve its outcome.

The primary endpoint was feasible two-dimensional hypervolume. Time was scaled by (T−0.7)/0.8, residual envelope by 1 μm, and the fixed reference was (1.1,1.1). No final feasible point lay outside that reference. A Python vertical-strip integration of rectangle unions independently recalculated HV. Final decisions, objectives, constraint violations, trajectories and source-manifest identities were audited. Separate MATLAB reevaluation covered all 26,880 final designs; these checks are reported separately from the optimizer budget.

Within each case, the combined method was compared with six controls using paired Wilcoxon signed ranks and Holm adjustment. Differences were rounded to 1e−12 to remove representation noise. Zero differences were omitted and ties assigned average ranks. Dynamic programming evaluated exact sign-assignment probabilities, under the symmetric-difference assumption of the test. Paired mean-difference intervals used 10,000 bootstrap resamples and a fixed analysis seed. These are individual 95% intervals, not simultaneous intervals adjusted for all comparisons. Failure to reject is not evidence of equivalence.

The factorial effects were A=[(A1B0−A0B0)+(A1B1−A0B1)]/2, B=[(A0B1−A0B0)+(A1B1−A1B0)]/2 and I=A1B1−A1B0−A0B1+A0B0, calculated for each seed. The three effects were Holm-adjusted within each case. No inferential pooling across the three requirement settings was used.

Engineering endpoints were the shortest returned feasible cycle satisfying residual-envelope thresholds of 0.05, 0.1 and 0.2 μm. Missing attainment was recorded explicitly, rather than replaced with zero. QMC cumulative feasibility and uncompressed archive counts have different meanings from MODE population quantities and were not treated as equivalent trajectories.

## 5. Results

'''
    validation=src[src.index('### 5.1 Numerical implementation checks'):src.index('### 5.3 Exploratory algorithm comparison')]
    validation+='''The formal-output audit passed for all 420 runs. Reevaluated objectives and aggregate constraint violations matched the saved values exactly. Independent HV calculations differed by at most 9.99×10⁻¹⁶. Of the 420 final populations, 419 were wholly feasible. The QMC run at the 2.5 s ceiling and seed 93111 had 63 feasible designs among 64 returned points; the infeasible point was excluded from every objective-space and engineering metric.

'''
    results='''### 5.3 Repeated algorithm comparison

Table 2 reports median HV over 20 runs. Complete means, standard deviations, ranges and individual observations are retained in the accompanying data.

'''+hvtable+'''
Table 3 compares the combined method with the baseline MODE. Differences are combined minus baseline; the paired mean difference must not be confused with a difference of separate medians.

'''+pairtable+'''
The combined method did not significantly outperform the baseline in any case. It also did not significantly outperform another MODE ablation variant. At the 2.5 s ceiling, it exceeded the two mixed-variable GA references and QMC after correction; at the 3.0 and 3.5 s ceilings, only the comparison with QMC reached the corrected threshold. Those comparisons do not attribute an advantage to the new mechanisms because the ablation contrasts failed to establish that attribution.

All nine A, B and interaction tests failed to reach the within-case corrected 0.05 level. At 2.5 s, B and I were exactly zero for 13 of 20 seeds after the numerical tolerance was applied. Median final archive category counts were one for all four MODE variants. This is consistent with limited opportunity for category stratification in the strict case. At 3.0 and 3.5 s, the stratified archives retained medians of five and seven categories, compared with approximately one to 1.5 and three for the global archives. Search memory therefore changed, but a significant HV benefit was not established.

The combined method had lower observed standard deviation than baseline MODE in the two relaxed cases. This is a descriptive observation, not a confirmed reduction in failure probability or a prespecified variance-test result. In particular, low-valued baseline runs influenced the positive mean differences while paired wins remained below half of the seeds.

Figure 2. Final HV distributions: each point is one run, horizontal marks are medians and thick vertical segments are interquartile ranges. Source: `analysis_formal/formal_hv_distribution.pdf`.

Figure 3. Median HV trajectories with interquartile shading. Source: `analysis_formal/formal_convergence.pdf`.

Figure 4. Factorial mean effects with individual 95% bootstrap intervals. Source: `analysis_formal/formal_factorial.pdf`. Statistical decisions use the separate Holm-adjusted signed-rank results.

### 5.4 Engineering endpoints

At the 0.1 μm threshold, both baseline and combined MODE attained a qualifying design in every run. Table 4 gives the median shortest returned cycle, not an experimentally measured cycle time.

'''+engtable+'''
The combined mechanisms did not consistently reduce this engineering endpoint. At the 2.5 s ceiling, neither method returned a design meeting the 0.05 μm threshold in any of its 20 runs. This is a search outcome and does not prove mathematical infeasibility. The numerical thresholds are comparison criteria, not validated machine positioning specifications.

### 5.5 Model-form sensitivity retained from development

Before the formal batch, ten extreme designs from the exploratory run were examined using a two-degree-of-freedom axial model. This separates the screw-end and nut/load coordinates, with shaft effective mass equal to one third of shaft mass under an assumed linear axial shape. It retains the same series static compliance and assigns the same assumed modal damping ratio. The ratio of its conservative modal-envelope sum to the single-mode envelope ranged from approximately 0.947 to 1.020 for those selected nominal-condition designs. This is not an error bound or validation of the formal optima. Both models omit torsion, the supporting structure and servo dynamics, and neither was calibrated against measurements.

### 5.6 Post-hoc finite-pool truncation diagnostic

After the repeated comparison, existing feasible final designs were pooled to investigate whether search performance and subset-compression quality were different issues. For each cycle ceiling, points from that case and stricter cases were eligible, because only the cycle constraint was relaxed. The three nondominated pools were separately reduced to 64 points by one-pass crowding distance, bounded-ear deletion and iteratively recomputed crowding distance. No new objective evaluations were made. This diagnostic uses results from many runs and is not another equal-budget optimizer comparison or a certified Pareto reference.

'''+pooltable+'''
Bounded-ear deletion improved finite-pool HV over one-pass crowding distance. Its values were close to iterative crowding-distance pruning, whose normalized pool-coverage radius was smaller in all three diagnostics. Thus a useful compression effect can coexist with a failure to improve the complete optimizer. The diagnostic also identifies iterative pruning as a necessary control for any subsequent archive-compression claim.

The feasible regions are nested as the cycle ceiling is relaxed, so the exact attainable HV cannot decrease. Nevertheless, most observed method medians were lower at 3.5 s than at 3.0 s. The HV of the pooled, uncompressed feasible sets increased from 0.961181 to 0.982546 and 0.986161. This supports interpreting the median decrease as a finite-budget search or retention difficulty, rather than a deterioration in the physical possibilities allowed by a longer cycle. One-pass compression itself can lose substantial HV and is not a reliable reference-front oracle.

'''
    discussion='''## 6. Discussion and limitations

The principal result is a separation between implementation correctness, finite-set representation and optimization benefit. The exact periodic evaluator passed independent numerical checks. The bounded-ear routine respected its finite-candidate coverage condition. Neither finding implied a measurable advantage in the complete MODE experiment. Convergence toward useful candidates, category allocation and preservation of extremes remain distinct from compressing a supplied candidate set.

Category-stratified memory retained more hardware alternatives when the cycle requirement was relaxed. Its smaller observed variability in some cases is a hypothesis-generating observation. The paired and factorial evidence does not justify claiming a confirmed robustness improvement, and no seeds were added or replaced to obtain significance. The appropriate next experiment would target a specified failure mode, rather than combine further operators without attribution.

The post-hoc compression diagnostic is informative but cannot rescue the failed optimizer claim. It combines multiple searches, uses larger pools than a single environmental-selection step, and was performed after observing the formal results. Iterative crowding distance nearly matched its HV and provided better pool coverage in these examples. Any follow-up claim about bounded geometric archives must compare against that stronger baseline under a new, prospectively fixed protocol.

One secondary logging requirement was incomplete: the implementation retained ear invocation counts, fallback counts and the largest bound excess, but not the absolute coverage radius at every generation. Those histories cannot be reconstructed from saved final populations and are not reported. The primary HV, engineering-endpoint and factorial analyses are unaffected. Runtime figures are host-specific; per-run search timers exclude file writes, and MODE timers also exclude initial model evaluation. Fixed method order and JIT effects prevent interpreting small runtime differences as portable complexity results.

Engineering interpretation remains restricted to the assumed linear axial model. Submicrometre residual envelopes are not submicrometre positioning accuracy for a clearance-containing transport screw. Stiffness variation and damping were assumed, not measured. Motor, thermal, contact and supporting-structure behavior remain outside the calculation. No claim of experimentally validated vibration, fatigue life, machine reliability or ready-to-purchase hardware is made.

## 7. Conclusions

The frozen numerical experiment completed 420 runs and 13,466,880 design evaluations. All saved final objectives and constraint violations were reproduced, and HV was independently checked. The proposed combination did not significantly outperform baseline MODE in any of the three cases, and no corrected factorial effect established a contribution from ear selection, stratified archiving or their interaction.

Bounded-ear truncation did improve the compression of three larger saved candidate pools relative to one-pass crowding distance. Its HV was close to iterative pruning, so this result supports a narrower archive-representation research question rather than a general optimizer-superiority claim. The engineering formulation and its verification artifacts provide a reproducible basis for that investigation, subject to the stated model and literature limitations.

'''
    tail=src[src.index('## References verified for this draft'):]
    tail=tail.replace('raw exploratory MAT files, CSV tables, figure scripts and a formal experiment protocol', 'the 420 formal MAT records, final-population and trajectory CSV files, independent audits, statistical scripts, figure scripts and the frozen experiment protocol')
    header='# Catalogue-constrained cycle-time and residual-vibration co-design of ball-screw actuators: evaluating coverage-bounded differential evolution\n\n**Formal numerical results revision, 21 September 2026.** The approved 420-run experiment is complete. This is a research draft with explicit negative findings and remaining literature/model limitations, not a submission candidate. Author information and declarations are not fabricated.\n\n'
    dest=ROOT/'manuscript/manuscript_en_formal_v02.md'; dest.write_text(header+abstract+intro+methods+validation+results+discussion+tail,encoding='utf-8')
    # Generate exact displayed numerical rows for the Chinese diagnostic table.
    zh=OUT/'RESULTS_zh.md'; text=zh.read_text(encoding='utf-8')
    a=text.index('|2.5 s|530|'); b=text.index('\n\n',a)
    text=text[:a]+''.join(poolrows).rstrip()+text[b:]; zh.write_text(text,encoding='utf-8')
    print(f'Wrote {dest}; {len(dest.read_text(encoding="utf-8").split())} words; numerical tables sourced from CSV.')

if __name__=='__main__': main()

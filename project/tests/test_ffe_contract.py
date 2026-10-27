from __future__ import annotations

import numpy as np

from alg1_replan.accounting import EvaluationCache, EvaluationLedger
from alg1_replan.cvgr_donor import degree_preserving_rewire, valid_reciprocal_pairs
from alg1_replan.cvgr_graph import GraphConfig, build_covio_graph, normalize_violation_profiles


def test_graph_pipeline_changes_ffe_by_zero() -> None:
    ledger = EvaluationLedger()
    raw = np.asarray([[1.0, 1.0, 0.0, 0.0]] * 12 + [[0.0, 0.0, 1.0, 1.0]] * 12)
    ledger.record_batch(24, source="synthetic_fixture_pre_evaluated")
    before = ledger.ffe

    profiles = normalize_violation_profiles(raw)
    graph = build_covio_graph(raw, GraphConfig())
    _ = valid_reciprocal_pairs(
        target_id="t",
        dominant_community=0,
        population_profiles={"t": [0.8, 0.2], "a": [0.1, 0.8]},
        union_profiles={"b": [0.9, 0.1]},
        relief_quantile=0.3,
        excluded_ids={"t"},
    )
    _ = degree_preserving_rewire(set(graph.edges), n_nodes=4, seed=123, n_swaps=4)

    assert profiles.shape == raw.shape
    assert ledger.ffe == before == 24


def test_cache_hit_does_not_increment_ffe_or_history() -> None:
    ledger = EvaluationLedger()
    cache = EvaluationCache(ledger=ledger)
    x = np.asarray([0.25, -0.5], dtype=np.float64)

    first = cache.evaluate_or_get(x, lambda _: (1.25, np.asarray([0.0, 0.5, 0.0])))
    history_after_first = cache.history_length
    second = cache.evaluate_or_get(x.copy(), lambda _: (_ for _ in ()).throw(AssertionError("must not evaluate")))

    assert first == second
    assert ledger.ffe == 1
    assert cache.history_length == history_after_first == 1


from __future__ import annotations

import numpy as np

from alg1_replan.cvgr_donor import select_cvgr_or_fallback, select_shade_donors
from alg1_replan.cvgr_graph import GraphConfig, build_covio_graph
from alg1_replan.randomness import split_rng_streams


def test_two_constraint_case_is_exact_parent_shade_fallback() -> None:
    raw = np.asarray([[1.0, 0.0], [0.0, 1.0]] * 12, dtype=float)
    graph = build_covio_graph(raw, GraphConfig())
    population_ids = tuple(range(12))
    archive_ids = tuple(range(100, 106))

    parent_base_rng, _ = split_rng_streams(3302822920)
    cvgr_base_rng, graph_rng = split_rng_streams(3302822920)
    expected = select_shade_donors(
        target_id=0,
        pbest_id=1,
        population_ids=population_ids,
        archive_ids=archive_ids,
        base_rng=parent_base_rng,
    )
    observed = select_cvgr_or_fallback(
        target_id=0,
        pbest_id=1,
        population_ids=population_ids,
        archive_ids=archive_ids,
        profiles=None,
        graph=graph,
        base_rng=cvgr_base_rng,
        graph_rng=graph_rng,
    )

    assert graph.fallback_reason == "TOO_FEW_CONSTRAINTS"
    assert observed.mode == "SHADE_FALLBACK"
    assert observed.donor_ids == expected.donor_ids


def test_graph_rng_consumption_cannot_advance_base_rng() -> None:
    untouched_base, graph_rng = split_rng_streams(2400725020)
    comparison_base, _ = split_rng_streams(2400725020)
    _ = graph_rng.integers(0, 2**31, size=1000)

    np.testing.assert_array_equal(
        untouched_base.integers(0, 2**31, size=20),
        comparison_base.integers(0, 2**31, size=20),
    )


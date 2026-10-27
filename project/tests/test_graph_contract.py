from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest

from alg1_replan.cvgr_graph import (  # production module intentionally absent in red phase
    GraphConfig,
    NonFiniteViolationError,
    build_covio_graph,
    normalize_violation_profiles,
    weighted_jaccard,
)


ROOT = Path(__file__).resolve().parents[1]
FIXTURE_PATH = ROOT / "artifacts" / "stage5" / "synthetic_falsification_fixtures_v0.1.json"


def load_fixture(fixture_id: str) -> dict:
    payload = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
    return next(row for row in payload["fixtures"] if row["id"] == fixture_id)


@pytest.fixture
def config() -> GraphConfig:
    return GraphConfig(
        kappa=20.0,
        edge_threshold=0.2,
        prevalence_min=0.05,
        prevalence_max=0.95,
        stability_threshold=0.6,
        profile_clip=10.0,
        minimum_constraints=3,
    )


def test_gold_two_block_graph_recovers_exact_components(config: GraphConfig) -> None:
    fixture = load_fixture("GOLD-BLOCK-2X2")
    raw = np.asarray(fixture["raw_violation_rows"], dtype=np.float64)
    graph = build_covio_graph(raw, config)

    assert graph.active_constraints == tuple(fixture["expected_active_constraints"])
    assert graph.edges == tuple(map(tuple, fixture["expected_edges"]))
    assert graph.components == tuple(tuple(x) for x in fixture["expected_components"])
    assert graph.nmi(tuple(tuple(x) for x in fixture["expected_components"])) == pytest.approx(1.0)


def test_graph_is_invariant_to_history_row_permutation(config: GraphConfig) -> None:
    source = load_fixture("GOLD-BLOCK-2X2")
    meta = load_fixture("META-ROW-PERMUTE")
    raw = np.asarray(source["raw_violation_rows"], dtype=np.float64)

    first = build_covio_graph(raw, config)
    second = build_covio_graph(raw[np.asarray(meta["permutation"], dtype=int)], config)

    np.testing.assert_allclose(first.weights, second.weights, rtol=0.0, atol=0.0)
    assert first.edges == second.edges
    assert first.components == second.components


def test_positive_constraint_rescaling_preserves_graph_and_profiles(config: GraphConfig) -> None:
    source = load_fixture("GOLD-BLOCK-2X2")
    meta = load_fixture("META-CONSTRAINT-RESCALE")
    raw = np.asarray(source["raw_violation_rows"], dtype=np.float64)
    scaled = raw * np.asarray(meta["constraint_scale_factors"], dtype=np.float64)

    graph_a = build_covio_graph(raw, config)
    graph_b = build_covio_graph(scaled, config)
    profile_a = normalize_violation_profiles(raw, clip=config.profile_clip)
    profile_b = normalize_violation_profiles(scaled, clip=config.profile_clip)

    np.testing.assert_allclose(graph_a.weights, graph_b.weights, rtol=0.0, atol=0.0)
    np.testing.assert_allclose(profile_a, profile_b, rtol=1e-12, atol=1e-12)


def test_balanced_independence_fails_closed_as_empty_graph(config: GraphConfig) -> None:
    fixture = load_fixture("GOLD-INDEPENDENT")
    graph = build_covio_graph(np.asarray(fixture["raw_violation_rows"], dtype=float), config)

    assert graph.edges == ()
    assert graph.activation is False
    assert graph.fallback_reason == fixture["expected_fallback_reason"]


def test_constant_violation_indicators_are_inactive_not_nan(config: GraphConfig) -> None:
    fixture = load_fixture("GOLD-CONSTANT-ALL-VIOLATED")
    graph = build_covio_graph(np.asarray(fixture["raw_violation_rows"], dtype=float), config)

    assert graph.active_constraints == ()
    assert np.isfinite(graph.weights).all()
    assert graph.fallback_reason == fixture["expected_fallback_reason"]


def test_nonfinite_residuals_raise_instead_of_imputation(config: GraphConfig) -> None:
    raw = np.asarray([[0.0, 1.0, 0.0], [1.0, np.nan, 0.0], [0.0, 1.0, np.inf]])
    with pytest.raises(NonFiniteViolationError):
        build_covio_graph(raw, config)


def test_weighted_jaccard_detects_disjoint_topologies() -> None:
    fixture = load_fixture("GOLD-UNSTABLE-GRAPH")
    observed = weighted_jaccard(
        fixture["previous_edges_with_weights"],
        fixture["current_edges_with_weights"],
        n_nodes=4,
    )
    assert observed == pytest.approx(fixture["expected_weighted_jaccard"])


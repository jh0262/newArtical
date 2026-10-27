from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest

from alg1_replan.cvgr_graph import GraphConfig, build_covio_graph


ROOT = Path(__file__).resolve().parents[1]
FIXTURE_PATH = (
    ROOT
    / "artifacts"
    / "stage5_amendment"
    / "synthetic_fallback_fixtures_I3_CVGR_v0.1.json"
)


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


def test_history_below_max_20_or_4m_returns_history_too_short(
    config: GraphConfig,
) -> None:
    fixture = load_fixture("AMEND-HISTORY-SHORT-M4")
    raw = np.asarray(fixture["raw_violation_rows"], dtype=np.float64)

    graph = build_covio_graph(raw, config)

    assert raw.shape == (19, 4)
    assert fixture["expected_n_min"] == max(20, 4 * raw.shape[1])
    assert graph.activation is False
    assert graph.fallback_reason == fixture["expected_fallback_reason"]


def test_complete_graph_returns_complete_graph_before_reference_check(
    config: GraphConfig,
) -> None:
    fixture = load_fixture("AMEND-COMPLETE-M3")
    graph = build_covio_graph(
        np.asarray(fixture["raw_violation_rows"], dtype=np.float64),
        config,
    )

    assert graph.edges == tuple(map(tuple, fixture["expected_edges"]))
    assert graph.activation is False
    assert graph.fallback_reason == fixture["expected_fallback_reason"]


def test_noncomplete_connected_graph_returns_single_community(
    config: GraphConfig,
) -> None:
    fixture = load_fixture("AMEND-SINGLE-COMMUNITY-CHAIN3")
    graph = build_covio_graph(
        np.asarray(fixture["raw_violation_rows"], dtype=np.float64),
        config,
    )

    assert graph.edges == tuple(map(tuple, fixture["expected_edges"]))
    assert graph.components == tuple(tuple(row) for row in fixture["expected_components"])
    assert graph.activation is False
    assert graph.fallback_reason == fixture["expected_fallback_reason"]


def test_otherwise_valid_graph_without_reference_returns_no_stability_reference(
    config: GraphConfig,
) -> None:
    fixture = load_fixture("AMEND-BLOCK4-NO-REFERENCE")
    graph = build_covio_graph(
        np.asarray(fixture["raw_violation_rows"], dtype=np.float64),
        config,
    )

    assert graph.edges == tuple(map(tuple, fixture["expected_edges"]))
    assert graph.components == tuple(tuple(row) for row in fixture["expected_components"])
    assert graph.activation is False
    assert graph.fallback_reason == fixture["expected_fallback_reason"]


def test_disjoint_consecutive_topology_returns_unstable_graph(
    config: GraphConfig,
) -> None:
    fixture = load_fixture("AMEND-UNSTABLE-DISJOINT4")
    previous = build_covio_graph(
        np.asarray(fixture["previous_raw_violation_rows"], dtype=np.float64),
        config,
    )
    current = build_covio_graph(
        np.asarray(fixture["current_raw_violation_rows"], dtype=np.float64),
        config,
        previous_graph=previous,
    )

    assert previous.edges == tuple(map(tuple, fixture["expected_previous_edges"]))
    assert current.edges == tuple(map(tuple, fixture["expected_current_edges"]))
    assert current.activation is False
    assert current.fallback_reason == fixture["expected_fallback_reason"]


def test_identical_consecutive_valid_graph_activates(config: GraphConfig) -> None:
    fixture = load_fixture("AMEND-BLOCK4-NO-REFERENCE")
    raw = np.asarray(fixture["raw_violation_rows"], dtype=np.float64)
    previous = build_covio_graph(raw, config)

    current = build_covio_graph(raw.copy(), config, previous_graph=previous)

    assert current.activation is True
    assert current.fallback_reason is None

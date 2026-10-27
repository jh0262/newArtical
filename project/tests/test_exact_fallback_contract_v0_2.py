from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest

from alg1_replan.cvgr_donor import select_cvgr_or_fallback, select_shade_donors
from alg1_replan.cvgr_graph import GraphConfig, build_covio_graph
from alg1_replan.randomness import split_rng_streams


ROOT = Path(__file__).resolve().parents[1]
FROZEN_FIXTURE_PATH = (
    ROOT / "artifacts" / "stage5" / "synthetic_falsification_fixtures_v0.1.json"
)
AMENDMENT_FIXTURE_PATH = (
    ROOT
    / "artifacts"
    / "stage5_amendment"
    / "synthetic_fallback_fixtures_I3_CVGR_v0.1.json"
)
POPULATION_IDS = tuple(range(12))
ARCHIVE_IDS = tuple(range(100, 106))


def _payload(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_fixture(fixture_id: str) -> dict:
    for path in (AMENDMENT_FIXTURE_PATH, FROZEN_FIXTURE_PATH):
        for row in _payload(path)["fixtures"]:
            if row["id"] == fixture_id:
                return row
    raise KeyError(fixture_id)


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


def inactive_graph(reason: str):
    source_by_reason = {
        "TOO_FEW_CONSTRAINTS": "GOLD-LOW-M2",
        "HISTORY_TOO_SHORT": "AMEND-HISTORY-SHORT-M4",
        "INSUFFICIENT_ACTIVE_CONSTRAINTS": "GOLD-CONSTANT-ALL-VIOLATED",
        "EMPTY_GRAPH": "GOLD-INDEPENDENT",
        "COMPLETE_GRAPH": "AMEND-COMPLETE-M3",
        "SINGLE_COMMUNITY": "AMEND-SINGLE-COMMUNITY-CHAIN3",
        "NO_STABILITY_REFERENCE": "AMEND-BLOCK4-NO-REFERENCE",
    }
    if reason == "UNSTABLE_GRAPH":
        fixture = load_fixture("AMEND-UNSTABLE-DISJOINT4")
        previous = build_covio_graph(
            np.asarray(fixture["previous_raw_violation_rows"], dtype=np.float64),
            config(),
        )
        graph = build_covio_graph(
            np.asarray(fixture["current_raw_violation_rows"], dtype=np.float64),
            config(),
            previous_graph=previous,
        )
    else:
        fixture = load_fixture(source_by_reason[reason])
        graph = build_covio_graph(
            np.asarray(fixture["raw_violation_rows"], dtype=np.float64),
            config(),
        )
    assert graph.fallback_reason == reason
    return graph


def active_graph():
    fixture = load_fixture("AMEND-BLOCK4-NO-REFERENCE")
    raw = np.asarray(fixture["raw_violation_rows"], dtype=np.float64)
    previous = build_covio_graph(raw, config())
    graph = build_covio_graph(raw.copy(), config(), previous_graph=previous)
    assert graph.activation is True
    assert graph.fallback_reason is None
    return graph


def profile_view(fixture: dict) -> dict:
    return {
        "population": {
            int(key): tuple(float(value) for value in row)
            for key, row in fixture["population_profiles"].items()
        },
        "union": {
            int(key): tuple(float(value) for value in row)
            for key, row in fixture["union_profiles"].items()
        },
    }


def assert_exact_parent_fallback(*, graph, profiles, reason: str, seed: int) -> None:
    parent_base_rng, _ = split_rng_streams(seed)
    cvgr_base_rng, graph_rng = split_rng_streams(seed)

    expected = select_shade_donors(
        target_id=0,
        pbest_id=1,
        population_ids=POPULATION_IDS,
        archive_ids=ARCHIVE_IDS,
        base_rng=parent_base_rng,
    )
    observed = select_cvgr_or_fallback(
        target_id=0,
        pbest_id=1,
        population_ids=POPULATION_IDS,
        archive_ids=ARCHIVE_IDS,
        profiles=profiles,
        graph=graph,
        base_rng=cvgr_base_rng,
        graph_rng=graph_rng,
    )

    assert observed.mode == "SHADE_FALLBACK"
    assert observed.fallback_reason == reason
    assert observed.donor_ids == expected.donor_ids
    np.testing.assert_array_equal(
        cvgr_base_rng.integers(0, 2**31, size=32),
        parent_base_rng.integers(0, 2**31, size=32),
    )


@pytest.mark.parametrize(
    "reason",
    [
        "TOO_FEW_CONSTRAINTS",
        "HISTORY_TOO_SHORT",
        "INSUFFICIENT_ACTIVE_CONSTRAINTS",
        "EMPTY_GRAPH",
        "COMPLETE_GRAPH",
        "SINGLE_COMMUNITY",
        "NO_STABILITY_REFERENCE",
        "UNSTABLE_GRAPH",
    ],
)
def test_every_graph_inactive_reason_is_exact_parent_fallback(reason: str) -> None:
    assert_exact_parent_fallback(
        graph=inactive_graph(reason),
        profiles=None,
        reason=reason,
        seed=3302822920,
    )


def test_no_valid_pair_is_exact_parent_fallback() -> None:
    fixture = load_fixture("AMEND-NO-VALID-PAIR")
    assert_exact_parent_fallback(
        graph=active_graph(),
        profiles=profile_view(fixture),
        reason=fixture["expected_fallback_reason"],
        seed=2400725020,
    )


def test_feasible_target_is_exact_parent_fallback() -> None:
    fixture = load_fixture("AMEND-FEASIBLE-TARGET")
    assert_exact_parent_fallback(
        graph=active_graph(),
        profiles=profile_view(fixture),
        reason=fixture["expected_fallback_reason"],
        seed=2780419743,
    )

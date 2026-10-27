from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from alg1_replan.cvgr_graph import GraphConfig, build_covio_graph
from alg1_replan.online_state import (
    OnlineCVGRController,
    RollingViolationHistory,
    community_profiles,
    current_scales,
    dominant_component,
    reprofile_records,
    resolve_fallback_reason,
)


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "artifacts" / "stage6_preimplementation" / "online_state_fixtures_I3_CVGR_v0.1.json"


def payload() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def test_rolling_history_retains_authorized_ffe_but_not_cache_hits() -> None:
    case = payload()["rolling_history"]
    history = RollingViolationHistory(case["population_size"], case["constraint_count"])
    for record_id in case["append_record_ids"]:
        history.append(record_id, case["raw_violation_template"], authorized_ffe=True, cache_hit=False)
    history.append(case["cache_hit_record_id"], case["raw_violation_template"], authorized_ffe=False, cache_hit=True)
    snapshot = history.snapshot()
    assert history.capacity == case["expected_capacity"]
    assert [row.record_id for row in snapshot] == case["expected_retained_ids"]
    assert len(snapshot) == case["expected_history_after_cache_hit"]


def test_current_scales_reprofile_archive_without_evaluation() -> None:
    case = payload()["scale_and_reprofile"]
    scales = current_scales(case["history"])
    np.testing.assert_allclose(scales, case["expected_scales"], rtol=0.0, atol=1e-15)
    observed = reprofile_records(case["archive_raw_by_id"], scales, clip=10.0)
    np.testing.assert_allclose(observed["A0"], case["expected_archive_profiles"]["A0"], rtol=0.0, atol=1e-15)


def test_activation_uses_previous_valid_graph_and_is_ledger_neutral() -> None:
    case = payload()["active_graph"]
    config = GraphConfig()
    previous = build_covio_graph(np.asarray(case["previous_raw_rows"], dtype=np.float64), config)
    controller = OnlineCVGRController(config)
    state = controller.update(
        history_rows=case["current_raw_rows"],
        previous_valid_graph=previous,
        population_raw={},
        archive_raw={},
    )
    assert state.activation is case["expected_activation"]
    assert [list(component) for component in state.graph.components] == case["expected_components"]
    assert state.graph.stability == case["expected_stability"]
    assert state.formal_ffe_delta == 0


def test_precedence_and_component_ties_are_deterministic() -> None:
    data = payload()
    for case in data["fallback_precedence"]:
        assert resolve_fallback_reason(case["true_conditions"]) == case["expected"]
    case = data["community_profiles"]
    means = community_profiles(case["profile"], case["components"])
    np.testing.assert_array_equal(means, np.asarray(case["expected_means"], dtype=np.float64))
    assert dominant_component(case["profile"], case["components"]) == case["expected_dominant_component"]
    assert dominant_component(case["tie_profile"], case["components"]) == case["expected_tie_component"]
    assert dominant_component(case["feasible_profile"], case["components"]) == case["expected_feasible_reason"]


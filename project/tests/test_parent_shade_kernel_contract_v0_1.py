from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from alg1_replan.shade_kernel import (
    ParentShadeState,
    midpoint_repair,
    trace_parent_generation,
    update_success_memory,
)
from alg1_replan.selection import CandidateRecord


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "artifacts" / "stage6_preimplementation" / "parent_shade_fixtures_I3_CVGR_v0.1.json"


def payload() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def candidate(row: dict) -> CandidateRecord:
    return CandidateRecord(
        stable_id=row["stable_id"],
        objective=row["objective"],
        violations=row["violations"],
        aggregate_violation=row.get("aggregate_violation"),
    )


def test_midpoint_bounds_repair_matches_parent_contract() -> None:
    case = payload()["midpoint_repair"]
    observed = midpoint_repair(case["trial"], case["target"], case["lower"], case["upper"])
    np.testing.assert_array_equal(observed, np.asarray(case["expected"], dtype=np.float64))


def test_success_history_uses_improvement_weighted_lehmer_means() -> None:
    case = payload()["success_memory"]
    memory_f, memory_cr, cursor = update_success_memory(
        case["memory_f"],
        case["memory_cr"],
        case["cursor"],
        case["successful_f"],
        case["successful_cr"],
        case["improvements"],
    )
    np.testing.assert_allclose(memory_f, case["expected_memory_f"], rtol=0.0, atol=1e-15)
    np.testing.assert_allclose(memory_cr, case["expected_memory_cr"], rtol=0.0, atol=1e-15)
    assert cursor == case["expected_cursor"]


def test_preevaluated_generation_trace_changes_no_ffe_or_history() -> None:
    case = payload()["one_generation_trace"]
    initial = case["state"]
    state = ParentShadeState(
        generation=initial["generation"],
        population=[candidate(row) for row in initial["population"]],
        vectors={row["stable_id"]: row["vector"] for row in initial["population"]},
        archive=[],
        archive_capacity=initial["archive_capacity"],
        memory_f=[0.5, 0.5],
        memory_cr=[0.5, 0.5],
        memory_cursor=0,
        ledger_ffe=initial["ledger_ffe"],
        history_length=initial["history_length"],
    )
    observed = trace_parent_generation(
        state=state,
        preevaluated_trials=case["preevaluated_trials"],
        deterministic_draws=case["deterministic_draws"],
    )
    expected = case["expected"]
    assert [row.stable_id for row in observed.population] == expected["selected_ids"]
    assert [row.stable_id for row in observed.archive] == expected["archive_ids"]
    assert observed.generation == expected["generation"]
    assert observed.ledger_ffe == expected["ledger_ffe"]
    assert observed.history_length == expected["history_length"]

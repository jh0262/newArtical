from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest

from alg1_replan.selection import CandidateRecord, compare_candidates, residuals_to_violations


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "artifacts" / "stage6_preimplementation" / "parent_shade_fixtures_I3_CVGR_v0.1.json"


def payload() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def record(data: dict) -> CandidateRecord:
    return CandidateRecord(
        stable_id=data["stable_id"],
        objective=data["objective"],
        violations=data["violations"],
        aggregate_violation=data.get("aggregate_violation"),
    )


def test_raw_residuals_are_converted_under_the_frozen_tolerance_rule() -> None:
    case = payload()["violation_conversion"]
    observed = residuals_to_violations(
        case["inequalities"], case["equalities"], case["equality_tolerances"]
    )
    np.testing.assert_allclose(observed, case["expected"], rtol=0.0, atol=1e-15)


@pytest.mark.parametrize("case", payload()["comparison_cases"], ids=lambda row: row["id"])
def test_every_comparator_uses_the_same_lexicographic_rule(case: dict) -> None:
    left = record(case["left"])
    right = record(case["right"])
    assert compare_candidates(left, right) == case["expected"]
    assert compare_candidates(right, left) == -case["expected"]


def test_nonfinite_residuals_and_negative_tolerances_are_rejected() -> None:
    with pytest.raises(ValueError):
        residuals_to_violations([np.nan], [], [])
    with pytest.raises(ValueError):
        residuals_to_violations([], [0.0], [-0.1])


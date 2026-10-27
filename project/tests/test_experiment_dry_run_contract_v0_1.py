from __future__ import annotations

import copy
import json
from pathlib import Path

import pytest

from alg1_replan.experiment_contracts import (
    DryRunEvaluatorForbidden,
    build_dry_run_bundle,
    resume_key,
    validate_config,
)


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "artifacts" / "stage6_preimplementation" / "dry_run_artifact_fixtures_I3_CVGR_v0.1.json"


def payload() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def test_registered_metadata_builds_a_zero_execution_dry_bundle() -> None:
    data = payload()
    config = data["config"]
    validate_config(config, data["registered_matrix_ids"], data["registered_failure_refs"])
    bundle = build_dry_run_bundle(config, data["environment"])
    expected = data["expected_bundle"]
    assert bundle["status"] == expected["status"]
    assert bundle["optimizer_runs"] == expected["optimizer_runs"] == 0
    assert bundle["objective_or_constraint_evaluations"] == expected["objective_or_constraint_evaluations"] == 0
    assert bundle["formal_ffe"] == expected["formal_ffe"] == 0
    assert bundle["formal_run_package_count"] == expected["formal_run_package_count"] == 0
    assert sorted(bundle["artifacts"]) == sorted(expected["artifact_kinds"])
    assert resume_key(
        config["matrix_row_id"], config["algorithm_id"], config["problem_id"], config["seed"], config["config_sha256"]
    ) == expected["resume_key"]


def test_unknown_ids_and_nonzero_dry_budget_are_rejected() -> None:
    data = payload()
    for case in data["invalid_cases"][:3]:
        config = copy.deepcopy(data["config"])
        if case["field"] == "matrix_row_id":
            config["matrix_row_id"] = case["value"]
        elif case["field"] == "failure_tree_refs":
            config["failure_tree_refs"] = case["value"]
        else:
            config[case["field"]] = case["value"]
        with pytest.raises(ValueError):
            validate_config(config, data["registered_matrix_ids"], data["registered_failure_refs"])


def test_callable_evaluator_is_structurally_forbidden() -> None:
    data = payload()
    config = copy.deepcopy(data["config"])
    config["evaluator"] = lambda _: (_ for _ in ()).throw(AssertionError("must never be called"))
    with pytest.raises(DryRunEvaluatorForbidden):
        validate_config(config, data["registered_matrix_ids"], data["registered_failure_refs"])

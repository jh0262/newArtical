"""Evaluator-forbidden, zero-execution experiment metadata contracts."""

from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import PurePosixPath
import re
from typing import Any, Mapping, Sequence


class DryRunEvaluatorForbidden(ValueError):
    """Raised when executable evaluation or optimization content is supplied."""


HASH_FIELDS = (
    "config_sha256",
    "preregistration_sha256",
    "method_sha256",
    "matrix_sha256",
    "failure_tree_sha256",
)
ZERO_EXECUTION_FIELDS = (
    "optimizer_runs",
    "objective_or_constraint_evaluations",
    "formal_ffe",
)
EXECUTION_KEYS = {
    "evaluator",
    "objective",
    "objective_function",
    "constraint",
    "constraint_function",
    "benchmark",
    "benchmark_adapter",
    "optimizer",
    "optimizer_loop",
    "run_hook",
    "execution_hook",
}
CONFIG_HASH_RULE = "SHA256_CANONICAL_JSON_EXCLUDING_CONFIG_SHA256"


def _walk_for_execution(value: Any, *, key: str | None = None) -> None:
    if callable(value):
        raise DryRunEvaluatorForbidden("callable values are forbidden in a dry-run config")
    if key in EXECUTION_KEYS and value not in (None, False):
        raise DryRunEvaluatorForbidden(f"execution field {key!r} is forbidden")
    if key == "callable" and value is not False:
        raise DryRunEvaluatorForbidden("adapter callable flag must be false")
    if isinstance(value, Mapping):
        for child_key, child_value in value.items():
            _walk_for_execution(child_value, key=str(child_key))
    elif isinstance(value, (list, tuple, set, frozenset)):
        for child in value:
            _walk_for_execution(child)


def _canonical_config_sha256(config: Mapping[str, Any]) -> str:
    payload = dict(config)
    payload.pop("config_sha256", None)
    try:
        encoded = json.dumps(
            payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise ValueError("config must contain JSON-compatible finite metadata") from exc
    return hashlib.sha256(encoded).hexdigest().upper()


def _validate_hash(value: Any, *, field: str) -> str:
    text = str(value)
    if re.fullmatch(r"[0-9A-Fa-f]{64}", text) is None:
        raise ValueError(f"{field} must be a 64-character SHA-256 digest")
    return text.upper()


def _validate_structure(config: Mapping[str, Any]) -> None:
    if not isinstance(config, Mapping):
        raise ValueError("config must be a mapping")
    _walk_for_execution(config)

    required = {
        "config_id",
        "config_hash_rule",
        *HASH_FIELDS,
        "matrix_row_id",
        "failure_tree_refs",
        "phase",
        "algorithm_id",
        "problem_id",
        "seed",
        *ZERO_EXECUTION_FIELDS,
        "adapter",
        "output_root",
    }
    missing = sorted(required - set(config))
    if missing:
        raise ValueError(f"missing required config fields: {missing}")
    if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*-v\d+\.\d+", str(config["config_id"])) is None:
        raise ValueError("config_id must be immutable and versioned as -vMAJOR.MINOR")
    if config["config_hash_rule"] != CONFIG_HASH_RULE:
        raise ValueError("unsupported config hash rule")
    for field in HASH_FIELDS:
        _validate_hash(config[field], field=field)
    expected_hash = _canonical_config_sha256(config)
    if str(config["config_sha256"]).upper() != expected_hash:
        raise ValueError("config_sha256 does not match canonical config metadata")

    for field in ZERO_EXECUTION_FIELDS:
        value = config[field]
        if isinstance(value, bool) or value != 0:
            raise ValueError(f"{field} must equal zero in a dry run")
    seed = config["seed"]
    if isinstance(seed, bool) or int(seed) != seed or seed < 0:
        raise ValueError("seed must be a non-negative integer")
    refs = config["failure_tree_refs"]
    if not isinstance(refs, (list, tuple)) or not refs:
        raise ValueError("failure_tree_refs must be a non-empty sequence")
    if len(refs) != len(set(refs)):
        raise ValueError("failure_tree_refs must not contain duplicates")
    adapter = config["adapter"]
    if not isinstance(adapter, Mapping):
        raise ValueError("adapter must be a metadata mapping")
    if adapter.get("kind") != "metadata_descriptor" or adapter.get("callable") is not False:
        raise DryRunEvaluatorForbidden(
            "adapter must be a non-callable metadata_descriptor"
        )
    output_root = PurePosixPath(str(config["output_root"]).replace("\\", "/"))
    if output_root.is_absolute() or ".." in output_root.parts or str(output_root) in {"", "."}:
        raise ValueError("output_root must be a non-empty relative path without traversal")

    for collection_name in ("cells", "runs"):
        rows = config.get(collection_name)
        if rows is None:
            continue
        if not isinstance(rows, Sequence) or isinstance(rows, (str, bytes)):
            raise ValueError(f"{collection_name} must be a sequence")
        keys: list[tuple[Any, Any]] = []
        for row in rows:
            if not isinstance(row, Mapping):
                raise ValueError(f"{collection_name} rows must be mappings")
            keys.append((row.get("matrix_row_id"), row.get("seed")))
        if len(keys) != len(set(keys)):
            raise ValueError("duplicate matrix-row/seed keys are forbidden")


def validate_config(
    config: Mapping[str, Any],
    registered_matrix_ids: Sequence[str],
    registered_failure_refs: Sequence[str],
) -> None:
    """Validate registered, immutable metadata without invoking any hook."""

    _validate_structure(config)
    matrix_ids = tuple(registered_matrix_ids)
    failure_refs = tuple(registered_failure_refs)
    if len(matrix_ids) != len(set(matrix_ids)) or len(failure_refs) != len(set(failure_refs)):
        raise ValueError("registered identity lists must not contain duplicates")
    if config["matrix_row_id"] not in set(matrix_ids):
        raise ValueError("matrix_row_id is not registered")
    unknown_refs = set(config["failure_tree_refs"]) - set(failure_refs)
    if unknown_refs:
        raise ValueError(f"unknown failure-tree references: {sorted(unknown_refs)}")


def resume_key(
    matrix_row_id: str,
    algorithm_id: str,
    problem_id: str,
    seed: int,
    config_sha256: str,
) -> str:
    """Construct the frozen collision-resistant logical run identity."""

    components = (
        str(matrix_row_id),
        str(algorithm_id),
        str(problem_id),
        str(seed),
        _validate_hash(config_sha256, field="config_sha256"),
    )
    if any(not component or "|" in component for component in components):
        raise ValueError("resume-key components must be non-empty and contain no pipe")
    return "|".join(components)


def build_dry_run_bundle(
    config: Mapping[str, Any], environment: Mapping[str, Any]
) -> dict[str, Any]:
    """Build planned JSON metadata in memory; create no run package or file."""

    _validate_structure(config)
    _walk_for_execution(environment)
    try:
        environment_copy = deepcopy(dict(environment))
        json.dumps(environment_copy, allow_nan=False)
    except (TypeError, ValueError) as exc:
        raise ValueError("environment must be JSON-compatible finite metadata") from exc

    root = PurePosixPath(str(config["output_root"]).replace("\\", "/"))
    key = resume_key(
        str(config["matrix_row_id"]),
        str(config["algorithm_id"]),
        str(config["problem_id"]),
        int(config["seed"]),
        str(config["config_sha256"]),
    )
    attempt_root = root / key.replace("|", "__") / "planned_attempt_000"
    identity = {
        field: deepcopy(config[field])
        for field in (
            "config_id",
            *HASH_FIELDS,
            "matrix_row_id",
            "failure_tree_refs",
            "phase",
            "algorithm_id",
            "problem_id",
            "seed",
        )
    }
    artifacts = {
        "manifest": {
            **identity,
            "status": "PLANNED_DRY_RUN_ONLY",
            "resume_key": key,
            "planned_path": str(attempt_root / "manifest.json"),
        },
        "environment": {
            "metadata": environment_copy,
            "planned_path": str(attempt_root / "environment.json"),
        },
        "log_header": {
            **identity,
            "status": "PLANNED_DRY_RUN_ONLY",
            "planned_path": str(attempt_root / "events.jsonl"),
        },
        "raw_result_schema": {
            "status": "SCHEMA_ONLY",
            "required": ["resume_key", "attempt_id", "status", "metrics"],
            "planned_path": str(attempt_root / "raw_result.json"),
        },
        "failure_schema": {
            "status": "SCHEMA_ONLY",
            "required": ["resume_key", "attempt_id", "failure_tree_ref", "message"],
            "preserve_prior_attempts": True,
            "planned_path": str(attempt_root / "failure.json"),
        },
        "resume_index": {
            "resume_key": key,
            "status": "PLANNED_ONLY_NO_EXISTING_PACKAGE_MUTATION",
            "complete_packages_overwritten": False,
            "planned_path": str(root / "resume_index.json"),
        },
    }
    return {
        "status": "PLANNED_DRY_RUN_ONLY",
        **identity,
        "optimizer_runs": 0,
        "objective_or_constraint_evaluations": 0,
        "formal_ffe": 0,
        "formal_run_package_count": 0,
        "artifacts": artifacts,
    }

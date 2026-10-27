"""Frozen feasibility and objective ordering for pre-evaluated candidates."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Sequence

import numpy as np


def _stable_key(value: Any) -> tuple[str, str]:
    return type(value).__name__, repr(value)


def _finite_vector(values: Sequence[float], *, name: str) -> np.ndarray:
    array = np.asarray(values, dtype=np.float64)
    if array.ndim != 1:
        raise ValueError(f"{name} must be one-dimensional")
    if not np.isfinite(array).all():
        raise ValueError(f"{name} must be finite")
    return array


@dataclass(frozen=True)
class CandidateRecord:
    """An immutable, already evaluated objective-and-violation record."""

    stable_id: Any
    objective: float
    violations: Sequence[float]
    aggregate_violation: float | None = None
    _violation_array: np.ndarray = field(init=False, repr=False, compare=False)

    def __post_init__(self) -> None:
        objective = float(self.objective)
        if not np.isfinite(objective):
            raise ValueError("objective must be finite")
        violations = _finite_vector(self.violations, name="violations")
        if np.any(violations < 0.0):
            raise ValueError("violations must be non-negative")
        aggregate = (
            float(np.sum(violations, dtype=np.float64))
            if self.aggregate_violation is None
            else float(self.aggregate_violation)
        )
        if not np.isfinite(aggregate) or aggregate < 0.0:
            raise ValueError("aggregate_violation must be finite and non-negative")
        immutable = violations.copy()
        immutable.setflags(write=False)
        object.__setattr__(self, "objective", objective)
        object.__setattr__(self, "violations", tuple(float(x) for x in immutable))
        object.__setattr__(self, "aggregate_violation", aggregate)
        object.__setattr__(self, "_violation_array", immutable)

    @property
    def feasible(self) -> bool:
        return bool(self.aggregate_violation <= 0.0)


def residuals_to_violations(
    inequalities: Sequence[float],
    equalities: Sequence[float],
    equality_tolerances: Sequence[float],
) -> np.ndarray:
    """Convert raw residuals without evaluating an objective or constraint."""

    inequality_array = _finite_vector(inequalities, name="inequalities")
    equality_array = _finite_vector(equalities, name="equalities")
    tolerance_array = _finite_vector(
        equality_tolerances, name="equality_tolerances"
    )
    if equality_array.size != tolerance_array.size:
        raise ValueError("equalities and equality_tolerances must have equal length")
    if np.any(tolerance_array < 0.0):
        raise ValueError("equality_tolerances must be non-negative")
    inequality_violations = np.maximum(0.0, inequality_array)
    equality_violations = np.maximum(0.0, np.abs(equality_array) - tolerance_array)
    return np.concatenate((inequality_violations, equality_violations))


def compare_candidates(left: CandidateRecord, right: CandidateRecord) -> int:
    """Return -1, 0 or 1 under the frozen deterministic lexicographic rule."""

    if left.feasible != right.feasible:
        return -1 if left.feasible else 1

    if not left.feasible and left.aggregate_violation != right.aggregate_violation:
        return -1 if left.aggregate_violation < right.aggregate_violation else 1

    if left.objective != right.objective:
        return -1 if left.objective < right.objective else 1

    left_key = _stable_key(left.stable_id)
    right_key = _stable_key(right.stable_id)
    if left_key == right_key:
        return 0
    return -1 if left_key < right_key else 1

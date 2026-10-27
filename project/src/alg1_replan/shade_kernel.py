"""Ledger-neutral SHADE parent-kernel transitions over pre-evaluated records."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping, Sequence

import numpy as np

from .selection import CandidateRecord, compare_candidates


def _vector(values: Sequence[float], *, name: str) -> np.ndarray:
    array = np.asarray(values, dtype=np.float64)
    if array.ndim != 1:
        raise ValueError(f"{name} must be one-dimensional")
    if not np.isfinite(array).all():
        raise ValueError(f"{name} must be finite")
    return array


def _contains_callable(value: Any) -> bool:
    if callable(value):
        return True
    if isinstance(value, Mapping):
        return any(_contains_callable(item) for item in value.values())
    if isinstance(value, (list, tuple, set, frozenset)):
        return any(_contains_callable(item) for item in value)
    return False


def midpoint_repair(
    trial: Sequence[float],
    target: Sequence[float],
    lower: Sequence[float],
    upper: Sequence[float],
) -> np.ndarray:
    """Apply the frozen parent-midpoint rule to an already assembled trial."""

    trial_array = _vector(trial, name="trial")
    target_array = _vector(target, name="target")
    lower_array = _vector(lower, name="lower")
    upper_array = _vector(upper, name="upper")
    if len({array.shape for array in (trial_array, target_array, lower_array, upper_array)}) != 1:
        raise ValueError("trial, target and bounds must have identical shapes")
    if np.any(lower_array > upper_array):
        raise ValueError("lower bounds must not exceed upper bounds")
    if np.any(target_array < lower_array) or np.any(target_array > upper_array):
        raise ValueError("target must lie within the bounds")

    repaired = trial_array.copy()
    below = repaired < lower_array
    above = repaired > upper_array
    repaired[below] = (lower_array[below] + target_array[below]) / 2.0
    repaired[above] = (upper_array[above] + target_array[above]) / 2.0
    return repaired


def _weighted_lehmer(values: np.ndarray, weights: np.ndarray) -> float:
    denominator = float(np.sum(weights * values, dtype=np.float64))
    if denominator <= 0.0:
        return 0.0
    numerator = float(np.sum(weights * values * values, dtype=np.float64))
    return numerator / denominator


def update_success_memory(
    memory_f: Sequence[float],
    memory_cr: Sequence[float],
    cursor: int,
    successful_f: Sequence[float],
    successful_cr: Sequence[float],
    improvements: Sequence[float],
) -> tuple[np.ndarray, np.ndarray, int]:
    """Update one circular memory slot from supplied positive improvements."""

    updated_f = _vector(memory_f, name="memory_f").copy()
    updated_cr = _vector(memory_cr, name="memory_cr").copy()
    if updated_f.size == 0 or updated_f.shape != updated_cr.shape:
        raise ValueError("SHADE memories must be non-empty and equally sized")
    cursor_value = int(cursor)
    if cursor_value != cursor or not 0 <= cursor_value < updated_f.size:
        raise ValueError("cursor must index the memory arrays")

    success_f = _vector(successful_f, name="successful_f")
    success_cr = _vector(successful_cr, name="successful_cr")
    gains = _vector(improvements, name="improvements")
    if len({success_f.size, success_cr.size, gains.size}) != 1:
        raise ValueError("successful parameters and improvements must have equal length")
    if success_f.size == 0:
        return updated_f, updated_cr, cursor_value
    if np.any(gains <= 0.0):
        raise ValueError("improvements must be strictly positive")
    if np.any(success_f <= 0.0) or np.any(success_f > 1.0):
        raise ValueError("successful_f must lie in (0, 1]")
    if np.any(success_cr < 0.0) or np.any(success_cr > 1.0):
        raise ValueError("successful_cr must lie in [0, 1]")

    weights = gains / float(np.sum(gains, dtype=np.float64))
    updated_f[cursor_value] = _weighted_lehmer(success_f, weights)
    updated_cr[cursor_value] = _weighted_lehmer(success_cr, weights)
    return updated_f, updated_cr, (cursor_value + 1) % updated_f.size


@dataclass(frozen=True)
class ParentShadeState:
    generation: int
    population: Sequence[CandidateRecord]
    vectors: Mapping[Any, Sequence[float]]
    archive: Sequence[CandidateRecord]
    archive_capacity: int
    memory_f: Sequence[float]
    memory_cr: Sequence[float]
    memory_cursor: int
    ledger_ffe: int
    history_length: int

    def __post_init__(self) -> None:
        if self.generation < 0 or self.archive_capacity < 0:
            raise ValueError("generation and archive_capacity must be non-negative")
        if self.ledger_ffe < 0 or self.history_length < 0:
            raise ValueError("ledger and history snapshots must be non-negative")
        population_ids = [row.stable_id for row in self.population]
        archive_ids = [row.stable_id for row in self.archive]
        if len(population_ids) != len(set(population_ids)):
            raise ValueError("population stable IDs must be unique")
        if len(archive_ids) != len(set(archive_ids)):
            raise ValueError("archive stable IDs must be unique")
        if any(identifier not in self.vectors for identifier in population_ids):
            raise ValueError("every population record must have a vector")
        shapes = {
            _vector(self.vectors[identifier], name="population vector").shape
            for identifier in population_ids
        }
        if len(shapes) > 1:
            raise ValueError("population vectors must have equal dimension")
        update_success_memory(
            self.memory_f, self.memory_cr, self.memory_cursor, [], [], []
        )


def _trial_record(row: Mapping[str, Any]) -> CandidateRecord:
    required = {"target_id", "stable_id", "vector", "objective", "violations", "improvement"}
    if not required.issubset(row):
        raise ValueError("pre-evaluated trial is missing a required field")
    improvement = float(row["improvement"])
    if not np.isfinite(improvement) or improvement <= 0.0:
        raise ValueError("trial improvement must be finite and strictly positive")
    return CandidateRecord(
        stable_id=row["stable_id"],
        objective=row["objective"],
        violations=row["violations"],
        aggregate_violation=row.get("aggregate_violation"),
    )


def trace_parent_generation(
    *,
    state: ParentShadeState,
    preevaluated_trials: Sequence[Mapping[str, Any]],
    deterministic_draws: Sequence[Mapping[str, Any]],
) -> ParentShadeState:
    """Trace one pre-evaluated parent state transition without an evaluator."""

    if _contains_callable(preevaluated_trials) or _contains_callable(deterministic_draws):
        raise ValueError("callable evaluators and execution hooks are forbidden")
    if len(preevaluated_trials) != len(deterministic_draws):
        raise ValueError("every pre-evaluated trial must have one deterministic draw")

    population_by_id = {row.stable_id: row for row in state.population}
    union_ids = set(population_by_id) | {row.stable_id for row in state.archive}
    trials_by_target: dict[Any, Mapping[str, Any]] = {}
    draws_by_target: dict[Any, Mapping[str, Any]] = {}
    for row in preevaluated_trials:
        target_id = row.get("target_id")
        if target_id in trials_by_target or target_id not in population_by_id:
            raise ValueError("trial target IDs must be unique members of the population")
        trials_by_target[target_id] = row
    for draw in deterministic_draws:
        required = {"target_id", "pbest_id", "r1_id", "r2_id", "f", "cr"}
        if not required.issubset(draw):
            raise ValueError("deterministic draw is missing a required field")
        target_id = draw["target_id"]
        if target_id in draws_by_target or target_id not in trials_by_target:
            raise ValueError("draw target IDs must uniquely match trial targets")
        parent_ids = (target_id, draw["pbest_id"], draw["r1_id"], draw["r2_id"])
        if len(set(parent_ids)) != 4:
            raise ValueError("target, p-best, r1 and r2 must be distinct")
        if draw["pbest_id"] not in population_by_id or draw["r1_id"] not in population_by_id:
            raise ValueError("p-best and r1 must belong to the population")
        if draw["r2_id"] not in union_ids:
            raise ValueError("r2 must belong to population plus archive")
        draws_by_target[target_id] = draw

    next_population = list(state.population)
    next_vectors = {
        identifier: _vector(vector, name="state vector").copy()
        for identifier, vector in state.vectors.items()
    }
    next_archive = list(state.archive)
    successful_f: list[float] = []
    successful_cr: list[float] = []
    improvements: list[float] = []

    positions = {row.stable_id: index for index, row in enumerate(state.population)}
    for target_id in (row.stable_id for row in state.population if row.stable_id in trials_by_target):
        trial_data = trials_by_target[target_id]
        trial = _trial_record(trial_data)
        trial_vector = _vector(trial_data["vector"], name="trial vector")
        target_vector = _vector(state.vectors[target_id], name="target vector")
        if trial_vector.shape != target_vector.shape:
            raise ValueError("trial and target vectors must have equal dimension")

        optional_bounds = (trial_data.get("lower"), trial_data.get("upper"))
        if any(value is not None for value in optional_bounds):
            if any(value is None for value in optional_bounds):
                raise ValueError("lower and upper trial bounds must be supplied together")
            trial_vector = midpoint_repair(
                trial_vector, target_vector, optional_bounds[0], optional_bounds[1]
            )

        parent = population_by_id[target_id]
        if compare_candidates(trial, parent) < 0:
            next_population[positions[target_id]] = trial
            next_vectors[trial.stable_id] = trial_vector.copy()
            if trial.stable_id != target_id:
                next_vectors.pop(target_id, None)
            next_archive.append(parent)
            draw = draws_by_target[target_id]
            successful_f.append(float(draw["f"]))
            successful_cr.append(float(draw["cr"]))
            improvements.append(float(trial_data["improvement"]))

    if state.archive_capacity == 0:
        next_archive = []
    elif len(next_archive) > state.archive_capacity:
        next_archive = next_archive[-state.archive_capacity :]

    memory_f, memory_cr, cursor = update_success_memory(
        state.memory_f,
        state.memory_cr,
        state.memory_cursor,
        successful_f,
        successful_cr,
        improvements,
    )
    return ParentShadeState(
        generation=state.generation + 1,
        population=tuple(next_population),
        vectors=next_vectors,
        archive=tuple(next_archive),
        archive_capacity=state.archive_capacity,
        memory_f=memory_f,
        memory_cr=memory_cr,
        memory_cursor=cursor,
        ledger_ffe=state.ledger_ffe,
        history_length=state.history_length,
    )

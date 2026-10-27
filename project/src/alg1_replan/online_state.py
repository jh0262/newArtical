"""Online CVGR state over already evaluated violation records."""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from typing import Any, Mapping, Sequence

import numpy as np

from .cvgr_donor import DonorSelection, select_cvgr_or_fallback
from .cvgr_graph import GraphConfig, GraphResult, build_covio_graph


FALLBACK_PRECEDENCE = (
    "TOO_FEW_CONSTRAINTS",
    "HISTORY_TOO_SHORT",
    "INSUFFICIENT_ACTIVE_CONSTRAINTS",
    "EMPTY_GRAPH",
    "COMPLETE_GRAPH",
    "SINGLE_COMMUNITY",
    "NO_STABILITY_REFERENCE",
    "UNSTABLE_GRAPH",
)


def _raw_vector(
    values: Sequence[float], *, name: str, expected_size: int | None = None
) -> np.ndarray:
    array = np.asarray(values, dtype=np.float64)
    if array.ndim != 1:
        raise ValueError(f"{name} must be one-dimensional")
    if expected_size is not None and array.size != expected_size:
        raise ValueError(f"{name} has an unexpected constraint count")
    if not np.isfinite(array).all():
        raise ValueError(f"{name} must be finite")
    if np.any(array < 0.0):
        raise ValueError(f"{name} must be non-negative")
    return array


def _raw_matrix(rows: Sequence[Sequence[float]], *, name: str) -> np.ndarray:
    array = np.asarray(rows, dtype=np.float64)
    if array.ndim != 2:
        raise ValueError(f"{name} must be two-dimensional")
    if not np.isfinite(array).all():
        raise ValueError(f"{name} must be finite")
    if np.any(array < 0.0):
        raise ValueError(f"{name} must be non-negative")
    return array


@dataclass(frozen=True)
class ViolationHistoryRecord:
    record_id: Any
    raw_violations: tuple[float, ...]


class RollingViolationHistory:
    """Chronological 5N window of authorized, non-cached FFE records."""

    def __init__(self, population_size: int, constraint_count: int) -> None:
        if int(population_size) != population_size or population_size <= 0:
            raise ValueError("population_size must be a positive integer")
        if int(constraint_count) != constraint_count or constraint_count <= 0:
            raise ValueError("constraint_count must be a positive integer")
        self.population_size = int(population_size)
        self.constraint_count = int(constraint_count)
        self.capacity = 5 * self.population_size
        self._rows: deque[ViolationHistoryRecord] = deque(maxlen=self.capacity)

    def append(
        self,
        record_id: Any,
        raw_violations: Sequence[float],
        *,
        authorized_ffe: bool = True,
        cache_hit: bool = False,
    ) -> None:
        if cache_hit:
            return
        if not authorized_ffe:
            raise ValueError("a non-cached history append requires an authorized FFE")
        raw = _raw_vector(
            raw_violations,
            name="raw_violations",
            expected_size=self.constraint_count,
        )
        self._rows.append(
            ViolationHistoryRecord(record_id, tuple(float(value) for value in raw))
        )

    def snapshot(self) -> tuple[ViolationHistoryRecord, ...]:
        return tuple(self._rows)


def _history_matrix(history: Sequence[Any]) -> np.ndarray:
    rows = [
        row.raw_violations if isinstance(row, ViolationHistoryRecord) else row
        for row in history
    ]
    return _raw_matrix(rows, name="history")


def current_scales(history: Sequence[Any]) -> np.ndarray:
    """Return the positive 0.75-quantile scale for each constraint."""

    raw = _history_matrix(history)
    if raw.shape[0] == 0 or raw.shape[1] == 0:
        raise ValueError("history must contain at least one row and constraint")
    scales = np.full(raw.shape[1], 1.0e-12, dtype=np.float64)
    for column in range(raw.shape[1]):
        positive = raw[:, column][raw[:, column] > 0.0]
        if positive.size:
            scales[column] = max(float(np.quantile(positive, 0.75)), 1.0e-12)
    return scales


def reprofile_records(
    raw_by_id: Mapping[Any, Sequence[float]],
    scales: Sequence[float],
    *,
    clip: float = 10.0,
) -> dict[Any, np.ndarray]:
    """Normalize stored raw residuals under the current scale without evaluation."""

    scale_array = _raw_vector(scales, name="scales")
    if scale_array.size == 0 or np.any(scale_array <= 0.0):
        raise ValueError("scales must be strictly positive")
    clip_value = float(clip)
    if not np.isfinite(clip_value) or clip_value <= 0.0:
        raise ValueError("clip must be finite and positive")
    return {
        identifier: np.minimum(
            _raw_vector(raw, name="raw record", expected_size=scale_array.size)
            / scale_array,
            clip_value,
        )
        for identifier, raw in raw_by_id.items()
    }


def _ordered_components(
    components: Sequence[Sequence[int]], *, profile_size: int
) -> tuple[tuple[int, ...], ...]:
    normalized = tuple(tuple(sorted(int(node) for node in group)) for group in components)
    if any(not group for group in normalized):
        raise ValueError("components must not be empty")
    if any(node < 0 or node >= profile_size for group in normalized for node in group):
        raise ValueError("component node is out of profile range")
    if len({node for group in normalized for node in group}) != sum(map(len, normalized)):
        raise ValueError("constraint nodes must not occur in multiple components")
    return tuple(sorted(normalized, key=lambda group: group[0]))


def community_profiles(
    profile: Sequence[float], components: Sequence[Sequence[int]]
) -> np.ndarray:
    """Aggregate a constraint profile into deterministic component means."""

    values = _raw_vector(profile, name="profile")
    ordered = _ordered_components(components, profile_size=values.size)
    return np.asarray(
        [float(np.mean(values[list(component)])) for component in ordered],
        dtype=np.float64,
    )


def dominant_component(
    profile: Sequence[float], components: Sequence[Sequence[int]]
) -> int | str:
    """Return the smallest component ID at the maximum, or feasible fallback."""

    values = _raw_vector(profile, name="profile")
    if not np.any(values > 0.0):
        return "FEASIBLE_TARGET"
    means = community_profiles(values, components)
    if means.size == 0:
        raise ValueError("at least one component is required")
    return int(np.argmax(means))


def resolve_fallback_reason(true_conditions: Sequence[str]) -> str | None:
    """Resolve simultaneous inactive conditions under the frozen precedence."""

    supplied = set(true_conditions)
    unknown = supplied - set(FALLBACK_PRECEDENCE)
    if unknown:
        raise ValueError(f"unknown fallback reason(s): {sorted(unknown)}")
    return next((reason for reason in FALLBACK_PRECEDENCE if reason in supplied), None)


@dataclass(frozen=True)
class OnlineCVGRState:
    graph: GraphResult
    activation: bool
    fallback_reason: str | None
    population_profiles: Mapping[Any, np.ndarray]
    archive_profiles: Mapping[Any, np.ndarray]
    next_valid_graph_reference: GraphResult | None
    formal_ffe_delta: int = 0


class OnlineCVGRController:
    """Ledger-neutral bridge from raw history to the frozen graph/donor core."""

    def __init__(self, graph_config: GraphConfig) -> None:
        if not isinstance(graph_config, GraphConfig):
            raise TypeError("graph_config must be a GraphConfig")
        self.graph_config = graph_config

    def update(
        self,
        *,
        history_rows: Sequence[Sequence[float]],
        previous_valid_graph: GraphResult | None,
        population_raw: Mapping[Any, Sequence[float]],
        archive_raw: Mapping[Any, Sequence[float]],
    ) -> OnlineCVGRState:
        raw = _raw_matrix(history_rows, name="history_rows")
        graph = build_covio_graph(
            raw, self.graph_config, previous_graph=previous_valid_graph
        )
        scales = current_scales(raw)
        population_constraint_profiles = reprofile_records(
            population_raw, scales, clip=self.graph_config.profile_clip
        )
        archive_constraint_profiles = reprofile_records(
            archive_raw, scales, clip=self.graph_config.profile_clip
        )
        components = graph.components
        population_profiles = {
            identifier: community_profiles(profile, components)
            for identifier, profile in population_constraint_profiles.items()
        }
        archive_profiles = {
            identifier: community_profiles(profile, components)
            for identifier, profile in archive_constraint_profiles.items()
        }
        structural_reason = graph.fallback_reason
        structurally_valid = structural_reason in {
            None,
            "NO_STABILITY_REFERENCE",
            "UNSTABLE_GRAPH",
        }
        next_reference = graph if structurally_valid else previous_valid_graph
        fallback_reason = resolve_fallback_reason(
            [] if graph.fallback_reason is None else [graph.fallback_reason]
        )
        return OnlineCVGRState(
            graph=graph,
            activation=graph.activation,
            fallback_reason=fallback_reason,
            population_profiles=population_profiles,
            archive_profiles=archive_profiles,
            next_valid_graph_reference=next_reference,
            formal_ffe_delta=0,
        )

    def select_donors(
        self,
        *,
        state: OnlineCVGRState,
        target_id: Any,
        pbest_id: Any,
        population_ids: Sequence[Any],
        archive_ids: Sequence[Any],
        base_rng: np.random.Generator,
        graph_rng: np.random.Generator,
        relief_quantile: float = 0.30,
    ) -> DonorSelection:
        union_profiles = dict(state.population_profiles)
        union_profiles.update(state.archive_profiles)
        return select_cvgr_or_fallback(
            target_id=target_id,
            pbest_id=pbest_id,
            population_ids=population_ids,
            archive_ids=archive_ids,
            profiles={
                "population": state.population_profiles,
                "union": union_profiles,
            },
            graph=state.graph,
            base_rng=base_rng,
            graph_rng=graph_rng,
            relief_quantile=relief_quantile,
        )

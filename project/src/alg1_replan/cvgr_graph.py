"""Deterministic shrinkage co-violation graph construction."""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Iterable, Sequence

import numpy as np


class NonFiniteViolationError(ValueError):
    """Raised when graph evidence contains NaN or infinity."""


@dataclass(frozen=True)
class GraphConfig:
    kappa: float = 20.0
    edge_threshold: float = 0.20
    prevalence_min: float = 0.05
    prevalence_max: float = 0.95
    stability_threshold: float = 0.60
    profile_clip: float = 10.0
    minimum_constraints: int = 3

    def __post_init__(self) -> None:
        if self.kappa < 0:
            raise ValueError("kappa must be non-negative")
        if not 0 <= self.edge_threshold <= 1:
            raise ValueError("edge_threshold must lie in [0, 1]")
        if not 0 <= self.prevalence_min <= self.prevalence_max <= 1:
            raise ValueError("invalid prevalence interval")
        if not 0 <= self.stability_threshold <= 1:
            raise ValueError("stability_threshold must lie in [0, 1]")
        if self.profile_clip <= 0 or self.minimum_constraints < 1:
            raise ValueError("profile_clip and minimum_constraints must be positive")


@dataclass(frozen=True)
class GraphResult:
    weights: np.ndarray
    active_constraints: tuple[int, ...]
    edges: tuple[tuple[int, int], ...]
    components: tuple[tuple[int, ...], ...]
    activation: bool
    fallback_reason: str | None
    stability: float | None = None

    def nmi(self, truth_components: Sequence[Sequence[int]]) -> float:
        """Normalized mutual information on the common labelled node set."""

        observed = _component_labels(self.components)
        truth = _component_labels(tuple(tuple(row) for row in truth_components))
        nodes = tuple(sorted(set(observed) & set(truth)))
        if not nodes:
            return 0.0

        obs_values = tuple(observed[node] for node in nodes)
        truth_values = tuple(truth[node] for node in nodes)
        n = float(len(nodes))
        obs_labels = sorted(set(obs_values))
        truth_labels = sorted(set(truth_values))
        obs_counts = {label: obs_values.count(label) for label in obs_labels}
        truth_counts = {label: truth_values.count(label) for label in truth_labels}

        mutual_information = 0.0
        for left in obs_labels:
            for right in truth_labels:
                joint = sum(
                    1 for observed_label, truth_label in zip(obs_values, truth_values, strict=True)
                    if observed_label == left and truth_label == right
                )
                if joint:
                    mutual_information += (joint / n) * math.log(
                        (joint * n) / (obs_counts[left] * truth_counts[right])
                    )

        entropy_obs = -sum((count / n) * math.log(count / n) for count in obs_counts.values())
        entropy_truth = -sum((count / n) * math.log(count / n) for count in truth_counts.values())
        denominator = math.sqrt(entropy_obs * entropy_truth)
        if math.isclose(denominator, 0.0, rel_tol=0.0, abs_tol=1.0e-15):
            return 1.0 if obs_values == truth_values else 0.0
        return mutual_information / denominator


def _component_labels(components: Sequence[Sequence[int]]) -> dict[int, int]:
    return {
        int(node): component_id
        for component_id, component in enumerate(components)
        for node in component
    }


def _validated_raw(raw_violation_rows: np.ndarray) -> np.ndarray:
    raw = np.asarray(raw_violation_rows, dtype=np.float64)
    if raw.ndim != 2:
        raise ValueError("violation history must be a two-dimensional array")
    if not np.isfinite(raw).all():
        raise NonFiniteViolationError("violation history contains NaN or infinity")
    if np.any(raw < 0):
        raise ValueError("violation history must contain non-negative violations")
    return raw


def normalize_violation_profiles(
    raw_violation_rows: np.ndarray,
    *,
    clip: float = 10.0,
) -> np.ndarray:
    """Quantile-normalize each violation column using positive observations."""

    if clip <= 0:
        raise ValueError("clip must be positive")
    raw = _validated_raw(raw_violation_rows)
    normalized = np.zeros_like(raw, dtype=np.float64)
    for column in range(raw.shape[1]):
        positive = raw[:, column][raw[:, column] > 0]
        if positive.size == 0:
            continue
        scale = max(float(np.quantile(positive, 0.75)), 1.0e-12)
        normalized[:, column] = np.minimum(raw[:, column] / scale, clip)
    return normalized


def _connected_components(
    active_constraints: tuple[int, ...],
    edges: tuple[tuple[int, int], ...],
) -> tuple[tuple[int, ...], ...]:
    adjacency = {node: set() for node in active_constraints}
    for left, right in edges:
        adjacency[left].add(right)
        adjacency[right].add(left)

    components: list[tuple[int, ...]] = []
    unseen = set(active_constraints)
    while unseen:
        start = min(unseen)
        stack = [start]
        members: list[int] = []
        unseen.remove(start)
        while stack:
            node = stack.pop()
            members.append(node)
            for neighbor in sorted(adjacency[node], reverse=True):
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    stack.append(neighbor)
        components.append(tuple(sorted(members)))
    return tuple(sorted(components, key=lambda component: component[0]))


def _thresholded_weight_map(graph: GraphResult) -> dict[tuple[int, int], float]:
    return {(left, right): float(graph.weights[left, right]) for left, right in graph.edges}


def weighted_jaccard(
    previous_edges_with_weights: Iterable[Sequence[float]],
    current_edges_with_weights: Iterable[Sequence[float]],
    *,
    n_nodes: int,
) -> float | None:
    """Weighted Jaccard over all undirected node pairs; absent edges are zero."""

    if n_nodes < 0:
        raise ValueError("n_nodes must be non-negative")

    def as_map(rows: Iterable[Sequence[float]]) -> dict[tuple[int, int], float]:
        result: dict[tuple[int, int], float] = {}
        for row in rows:
            if len(row) != 3:
                raise ValueError("each weighted edge must be (left, right, weight)")
            left, right, weight = int(row[0]), int(row[1]), float(row[2])
            if left == right or not 0 <= left < n_nodes or not 0 <= right < n_nodes:
                raise ValueError("invalid undirected edge")
            key = tuple(sorted((left, right)))
            result[key] = weight
        return result

    previous = as_map(previous_edges_with_weights)
    current = as_map(current_edges_with_weights)
    keys = set(previous) | set(current)
    denominator = sum(max(previous.get(key, 0.0), current.get(key, 0.0)) for key in keys)
    if denominator <= 0.0:
        return None
    numerator = sum(min(previous.get(key, 0.0), current.get(key, 0.0)) for key in keys)
    return numerator / denominator


def build_covio_graph(
    raw_violation_rows: np.ndarray,
    config: GraphConfig,
    *,
    previous_graph: GraphResult | None = None,
) -> GraphResult:
    """Build the frozen deterministic graph and evaluate activation precedence."""

    raw = _validated_raw(raw_violation_rows)
    n_rows, n_constraints = raw.shape
    weights = np.zeros((n_constraints, n_constraints), dtype=np.float64)

    if n_constraints < config.minimum_constraints:
        return GraphResult(weights, (), (), (), False, "TOO_FEW_CONSTRAINTS")
    if n_rows < max(20, 4 * n_constraints):
        return GraphResult(weights, (), (), (), False, "HISTORY_TOO_SHORT")

    binary = raw > 0
    prevalence = binary.mean(axis=0)
    active_constraints = tuple(
        int(index)
        for index, value in enumerate(prevalence)
        if config.prevalence_min <= value <= config.prevalence_max
    )
    if len(active_constraints) < config.minimum_constraints:
        return GraphResult(
            weights,
            active_constraints,
            (),
            tuple((node,) for node in active_constraints),
            False,
            "INSUFFICIENT_ACTIVE_CONSTRAINTS",
        )

    shrinkage = n_rows / (n_rows + config.kappa)
    for position, left in enumerate(active_constraints):
        p_left = prevalence[left]
        for right in active_constraints[position + 1 :]:
            p_right = prevalence[right]
            denominator = math.sqrt(
                p_left * (1.0 - p_left) * p_right * (1.0 - p_right)
            )
            phi = 0.0
            if denominator > 0.0:
                p_joint = float(np.logical_and(binary[:, left], binary[:, right]).mean())
                phi = (p_joint - p_left * p_right) / denominator
            weight = max(0.0, shrinkage * phi)
            weights[left, right] = weight
            weights[right, left] = weight

    edges = tuple(
        (left, right)
        for position, left in enumerate(active_constraints)
        for right in active_constraints[position + 1 :]
        if weights[left, right] >= config.edge_threshold
    )
    components = _connected_components(active_constraints, edges)

    if not edges:
        return GraphResult(weights, active_constraints, edges, components, False, "EMPTY_GRAPH")
    if len(edges) == math.comb(len(active_constraints), 2):
        return GraphResult(weights, active_constraints, edges, components, False, "COMPLETE_GRAPH")
    if len(components) < 2:
        return GraphResult(weights, active_constraints, edges, components, False, "SINGLE_COMMUNITY")
    if previous_graph is None:
        return GraphResult(
            weights,
            active_constraints,
            edges,
            components,
            False,
            "NO_STABILITY_REFERENCE",
        )

    previous_rows = [(*edge, weight) for edge, weight in _thresholded_weight_map(previous_graph).items()]
    current_rows = [(*edge, weight) for edge, weight in _thresholded_weight_map(
        GraphResult(weights, active_constraints, edges, components, False, None)
    ).items()]
    stability = weighted_jaccard(previous_rows, current_rows, n_nodes=n_constraints)
    if stability is None or stability < config.stability_threshold:
        return GraphResult(
            weights,
            active_constraints,
            edges,
            components,
            False,
            "UNSTABLE_GRAPH",
            stability,
        )
    return GraphResult(weights, active_constraints, edges, components, True, None, stability)

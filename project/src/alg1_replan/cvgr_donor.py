"""Deterministic donor-domain helpers for the CVGR mechanism core."""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any, Iterable, Mapping, Sequence

import numpy as np

from .cvgr_graph import GraphResult


Identifier = Any
Profiles = Mapping[Identifier, Sequence[float]]


@dataclass(frozen=True)
class DonorSelection:
    mode: str
    donor_ids: tuple[Identifier, Identifier]
    fallback_reason: str | None = None
    dominant_community: int | None = None


def _stable_key(value: Identifier) -> tuple[str, str]:
    return type(value).__name__, repr(value)


def valid_reciprocal_pairs(
    *,
    target_id: Identifier,
    dominant_community: int,
    population_profiles: Profiles,
    union_profiles: Profiles,
    relief_quantile: float,
    excluded_ids: set[Identifier] | frozenset[Identifier],
) -> tuple[tuple[Identifier, Identifier], ...]:
    """Enumerate frozen ordered relief/complement pairs deterministically."""

    del target_id  # target membership is governed by excluded_ids.
    if not 0 < relief_quantile <= 1:
        raise ValueError("relief_quantile must lie in (0, 1]")
    if not population_profiles:
        return ()

    dimensions = {len(tuple(profile)) for profile in population_profiles.values()}
    dimensions.update(len(tuple(profile)) for profile in union_profiles.values())
    if len(dimensions) != 1:
        raise ValueError("all profiles must have the same dimensionality")
    dimension = next(iter(dimensions))
    if not 0 <= dominant_community < dimension:
        raise ValueError("dominant_community is out of range")

    eligible_population = [
        identifier for identifier in population_profiles if identifier not in excluded_ids
    ]
    if not eligible_population:
        return ()
    pool_size = min(
        len(eligible_population),
        max(1, math.ceil(relief_quantile * len(population_profiles))),
    )
    ranked = sorted(
        eligible_population,
        key=lambda identifier: (
            float(population_profiles[identifier][dominant_community]),
            _stable_key(identifier),
        ),
    )
    relief_pool = ranked[:pool_size]

    pairs: list[tuple[Identifier, Identifier]] = []
    for positive_id in relief_pool:
        positive = np.asarray(population_profiles[positive_id], dtype=np.float64)
        if not np.isfinite(positive).all():
            raise ValueError("profiles must be finite")
        for negative_id in sorted(union_profiles, key=_stable_key):
            if negative_id in excluded_ids or negative_id == positive_id:
                continue
            negative = np.asarray(union_profiles[negative_id], dtype=np.float64)
            if not np.isfinite(negative).all():
                raise ValueError("profiles must be finite")
            relieves = positive[dominant_community] < negative[dominant_community]
            complements = any(
                positive[index] > negative[index]
                for index in range(dimension)
                if index != dominant_community
            )
            if relieves and complements:
                pairs.append((positive_id, negative_id))
    return tuple(pairs)


def degree_preserving_rewire(
    edges: Iterable[tuple[int, int]],
    *,
    n_nodes: int,
    seed: int,
    n_swaps: int,
) -> set[tuple[int, int]]:
    """Perform deterministic simple-graph double-edge swap attempts."""

    normalized = {tuple(sorted((int(left), int(right)))) for left, right in edges}
    if any(left == right for left, right in normalized):
        raise ValueError("self-loops are not permitted")
    if any(left < 0 or right >= n_nodes for left, right in normalized):
        raise ValueError("edge endpoint out of range")
    if n_swaps < 0:
        raise ValueError("n_swaps must be non-negative")

    rng = np.random.default_rng(int(seed))
    rewired = set(normalized)
    successful = 0
    attempts = 0
    max_attempts = max(20, n_swaps * 20)
    while successful < n_swaps and attempts < max_attempts and len(rewired) >= 2:
        attempts += 1
        ordered = sorted(rewired)
        selected = rng.choice(len(ordered), size=2, replace=False)
        first = ordered[int(selected[0])]
        second = ordered[int(selected[1])]
        a, b = first
        c, d = second
        if len({a, b, c, d}) < 4:
            continue
        if int(rng.integers(0, 2)) == 0:
            proposals = {tuple(sorted((a, c))), tuple(sorted((b, d)))}
        else:
            proposals = {tuple(sorted((a, d))), tuple(sorted((b, c)))}
        if len(proposals) != 2 or any(left == right for left, right in proposals):
            continue
        remaining = rewired - {first, second}
        if proposals & remaining:
            continue
        rewired = remaining | proposals
        successful += 1
    return rewired


def select_shade_donors(
    *,
    target_id: Identifier,
    pbest_id: Identifier,
    population_ids: Sequence[Identifier],
    archive_ids: Sequence[Identifier],
    base_rng: np.random.Generator,
) -> DonorSelection:
    """Sample the parent SHADE ordered difference pair from frozen domains."""

    r1_domain = [
        identifier
        for identifier in population_ids
        if identifier not in {target_id, pbest_id}
    ]
    if not r1_domain:
        raise ValueError("no valid r1 donor")
    r1 = r1_domain[int(base_rng.integers(0, len(r1_domain)))]
    r2_domain = [
        identifier
        for identifier in tuple(population_ids) + tuple(archive_ids)
        if identifier not in {target_id, pbest_id, r1}
    ]
    if not r2_domain:
        raise ValueError("no valid r2 donor")
    r2 = r2_domain[int(base_rng.integers(0, len(r2_domain)))]
    return DonorSelection(mode="SHADE", donor_ids=(r1, r2))


def select_cvgr_or_fallback(
    *,
    target_id: Identifier,
    pbest_id: Identifier,
    population_ids: Sequence[Identifier],
    archive_ids: Sequence[Identifier],
    profiles: Mapping[str, Profiles] | None,
    graph: GraphResult,
    base_rng: np.random.Generator,
    graph_rng: np.random.Generator,
    relief_quantile: float = 0.30,
) -> DonorSelection:
    """Select a graph pair or invoke an exact parent-RNG fallback."""

    def fallback(reason: str) -> DonorSelection:
        parent = select_shade_donors(
            target_id=target_id,
            pbest_id=pbest_id,
            population_ids=population_ids,
            archive_ids=archive_ids,
            base_rng=base_rng,
        )
        return DonorSelection(
            mode="SHADE_FALLBACK",
            donor_ids=parent.donor_ids,
            fallback_reason=reason,
        )

    if not graph.activation:
        return fallback(graph.fallback_reason or "UNSTABLE_GRAPH")
    if profiles is None:
        return fallback("NO_VALID_PAIR")

    population_profiles = profiles["population"]
    union_profiles = profiles["union"]
    target_profile = np.asarray(population_profiles[target_id], dtype=np.float64)
    if not np.isfinite(target_profile).all():
        raise ValueError("target profile must be finite")
    if not np.any(target_profile):
        return fallback("FEASIBLE_TARGET")

    dominant_community = int(np.argmax(target_profile))
    pairs = valid_reciprocal_pairs(
        target_id=target_id,
        dominant_community=dominant_community,
        population_profiles=population_profiles,
        union_profiles=union_profiles,
        relief_quantile=relief_quantile,
        excluded_ids={target_id, pbest_id},
    )
    if not pairs:
        return fallback("NO_VALID_PAIR")
    selected = pairs[int(graph_rng.integers(0, len(pairs)))]
    return DonorSelection(
        mode="CVGR",
        donor_ids=selected,
        dominant_community=dominant_community,
    )

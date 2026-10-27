from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

import numpy as np

from alg1_replan.cvgr_donor import (  # production module intentionally absent in red phase
    degree_preserving_rewire,
    valid_reciprocal_pairs,
)


ROOT = Path(__file__).resolve().parents[1]
FIXTURE_PATH = ROOT / "artifacts" / "stage5" / "synthetic_falsification_fixtures_v0.1.json"


def load_fixture(fixture_id: str) -> dict:
    payload = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
    return next(row for row in payload["fixtures"] if row["id"] == fixture_id)


def test_reciprocal_pair_order_has_relief_then_complement() -> None:
    fixture = load_fixture("GOLD-RECIPROCAL-PAIR")
    pairs = valid_reciprocal_pairs(
        target_id="target",
        dominant_community=fixture["dominant_community"],
        population_profiles=fixture["population_profiles"],
        union_profiles=fixture["union_profiles"],
        relief_quantile=0.3,
        excluded_ids={"target"},
    )

    assert set(pairs) == {tuple(x) for x in fixture["expected_valid_pair_ids"]}
    for positive_id, negative_id in pairs:
        positive = np.asarray(fixture["population_profiles"][positive_id], dtype=float)
        negative = np.asarray(fixture["union_profiles"][negative_id], dtype=float)
        c = fixture["dominant_community"]
        assert positive[c] < negative[c]
        assert any(positive[d] > negative[d] for d in range(len(positive)) if d != c)


def test_degree_preserving_control_keeps_degree_sequence_and_simple_graph() -> None:
    edges = {(0, 1), (0, 2), (1, 3), (2, 3), (3, 4), (4, 5)}
    rewired = degree_preserving_rewire(edges, n_nodes=6, seed=104729, n_swaps=40)

    def degree_sequence(items: set[tuple[int, int]]) -> list[int]:
        counts: Counter[int] = Counter()
        for left, right in items:
            counts[left] += 1
            counts[right] += 1
        return sorted(counts[i] for i in range(6))

    assert len(rewired) == len(edges)
    assert all(left != right for left, right in rewired)
    assert len({tuple(sorted(edge)) for edge in rewired}) == len(rewired)
    assert degree_sequence(rewired) == degree_sequence(edges)


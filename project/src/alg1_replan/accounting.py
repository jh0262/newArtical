"""FFE accounting and a deterministic decision-vector evaluation cache."""

from __future__ import annotations

from dataclasses import dataclass, field
import hashlib
from typing import Callable

import numpy as np


Evaluation = tuple[float, np.ndarray]


@dataclass
class EvaluationLedger:
    """Count evaluator calls; graph-side operations never receive this ledger."""

    ffe: int = 0
    records: list[dict[str, object]] = field(default_factory=list)

    def record_batch(self, count: int, *, source: str) -> None:
        if not isinstance(count, int) or count < 0:
            raise ValueError("count must be a non-negative integer")
        self.ffe += count
        self.records.append({"count": count, "source": str(source)})

    def record_evaluation(self, *, source: str = "evaluator") -> None:
        self.record_batch(1, source=source)


class EvaluationCache:
    """Cache exact float64 decision vectors without creating history on hits."""

    def __init__(self, *, ledger: EvaluationLedger) -> None:
        self.ledger = ledger
        self._cache: dict[str, Evaluation] = {}
        self._history: list[tuple[str, Evaluation]] = []

    @staticmethod
    def _key(x: np.ndarray) -> str:
        vector = np.ascontiguousarray(np.asarray(x, dtype=np.float64))
        if vector.ndim != 1:
            raise ValueError("decision vector must be one-dimensional")
        payload = vector.dtype.str.encode("ascii") + vector.shape[0].to_bytes(8, "big") + vector.tobytes()
        return hashlib.sha256(payload).hexdigest()

    @property
    def history_length(self) -> int:
        return len(self._history)

    def evaluate_or_get(
        self,
        x: np.ndarray,
        evaluator: Callable[[np.ndarray], Evaluation],
    ) -> Evaluation:
        key = self._key(x)
        if key in self._cache:
            return self._cache[key]

        objective, residuals = evaluator(np.asarray(x, dtype=np.float64).copy())
        result: Evaluation = (float(objective), np.asarray(residuals, dtype=np.float64).copy())
        self.ledger.record_evaluation(source="cache_miss")
        self._cache[key] = result
        self._history.append((key, result))
        return result

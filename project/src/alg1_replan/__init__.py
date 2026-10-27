"""Deterministic CVGR mechanism core.

This package intentionally contains no optimizer loop or benchmark evaluator.
"""

from .accounting import EvaluationCache, EvaluationLedger
from .cvgr_graph import GraphConfig, GraphResult, NonFiniteViolationError

__all__ = [
    "EvaluationCache",
    "EvaluationLedger",
    "GraphConfig",
    "GraphResult",
    "NonFiniteViolationError",
]

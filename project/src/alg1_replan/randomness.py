"""Domain-separated NumPy random streams for the CVGR mechanism."""

from __future__ import annotations

import hashlib

import numpy as np


def _domain_seed(run_seed: int, label: str) -> int:
    payload = f"ALG1-Replan|CVGR|{label}|{int(run_seed)}".encode("utf-8")
    digest = hashlib.sha256(payload).digest()
    return int.from_bytes(digest[:16], byteorder="big", signed=False)


def split_rng_streams(run_seed: int) -> tuple[np.random.Generator, np.random.Generator]:
    """Return independent deterministic streams for parent and graph draws."""

    return (
        np.random.Generator(np.random.PCG64(_domain_seed(run_seed, "base_rng"))),
        np.random.Generator(np.random.PCG64(_domain_seed(run_seed, "graph_rng"))),
    )

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


QUERIES = (
    "constraint constraint co-violation graph donor selection differential evolution",
    "constraint co-occurrence network evolutionary optimization recombination",
    "multiple constraint interaction graph constrained optimization population",
    "constraint correlation matrix donor selection differential evolution constrained",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Capture reproducible local FAISS novelty searches for I3-CVGR."
    )
    parser.add_argument("--output", required=True)
    parser.add_argument("--top-k", type=int, default=30)
    args = parser.parse_args()

    workspace = Path(__file__).resolve().parents[3]
    wanted_python = (workspace / ".venv-v3" / "Scripts" / "python.exe").resolve()
    if wanted_python.exists() and Path(sys.executable).resolve() != wanted_python:
        environment = os.environ.copy()
        dependencies = str((workspace / ".v3deps").resolve())
        environment["PYTHONPATH"] = dependencies + (
            os.pathsep + environment["PYTHONPATH"]
            if environment.get("PYTHONPATH")
            else ""
        )
        environment.setdefault("HF_HOME", str((workspace / ".models").resolve()))
        completed = subprocess.run(
            [str(wanted_python), str(Path(__file__).resolve()), *sys.argv[1:]],
            env=environment,
            check=False,
        )
        raise SystemExit(completed.returncode)

    shared_scripts = workspace / "scripts"
    sys.path.insert(0, str(shared_scripts))

    from semantic_search import FAISS_META_PATH, FAISS_PATH, semantic_search

    runs = []
    for index, query in enumerate(QUERIES, 1):
        payload = semantic_search(query, top_k=args.top_k)
        runs.append(
            {
                "run_id": f"SEM-{index}",
                "query": query,
                "expanded_query": payload["expanded_query"],
                "expansion_terms": payload["expansion_terms"],
                "model_id": payload["model_id"],
                "result_count": len(payload["results"]),
                "results": payload["results"],
            }
        )

    artifact = {
        "schema": "alg1_replan.semantic_novelty_search.v1",
        "candidate": "I3-CVGR",
        "executed_at": "2026-08-30",
        "generator_visible": False,
        "channel": "SEMANTIC",
        "engine": "local sentence-transformer embeddings plus FAISS inner-product search",
        "faiss_index": {
            "path": "04_index/faiss.index",
            "sha256": sha256(FAISS_PATH),
        },
        "faiss_metadata": {
            "path": "04_index/faiss_metadata.json",
            "sha256": sha256(FAISS_META_PATH),
        },
        "top_k": args.top_k,
        "runs": runs,
        "claim_boundary": (
            "A successful semantic search proves only that the declared local index was queried. "
            "Absence of a target-equivalent hit is not proof of novelty, and all candidate hits "
            "require paper-level verification."
        ),
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(artifact, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(output), "runs": len(runs), "top_k": args.top_k}, ensure_ascii=False))


if __name__ == "__main__":
    main()

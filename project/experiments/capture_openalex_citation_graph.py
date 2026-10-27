from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time
from typing import Any
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


ANCHORS = (
    "10.1016/j.ins.2024.121863",
    "10.1109/CEC.2015.7257045",
    "10.1109/TEVC.2015.2477402",
)
BASE = "https://api.openalex.org"
USER_AGENT = "ALG1-Replan literature audit (mailto:research@example.invalid)"


def fetch_json(url: str, retries: int = 3) -> dict[str, Any]:
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            request = Request(url, headers={"User-Agent": USER_AGENT})
            with urlopen(request, timeout=30) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception as exc:  # network evidence must surface terminal failure
            last_error = exc
            if attempt + 1 < retries:
                time.sleep(0.5 * (attempt + 1))
    raise RuntimeError(f"OpenAlex request failed after {retries} attempts: {url}") from last_error


def compact(work: dict[str, Any]) -> dict[str, Any]:
    primary = work.get("primary_location") or {}
    source = primary.get("source") or {}
    return {
        "id": work.get("id"),
        "doi": work.get("doi"),
        "title": work.get("display_name"),
        "year": work.get("publication_year"),
        "type": work.get("type"),
        "cited_by_count": work.get("cited_by_count"),
        "venue": source.get("display_name"),
    }


def work_by_id(openalex_id: str) -> dict[str, Any]:
    normalized_id = openalex_id.rstrip("/").rsplit("/", 1)[-1]
    return fetch_json(f"{BASE}/works/{quote(normalized_id)}")


def related_records(ids: list[str], limit: int = 60) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    unique = list(dict.fromkeys(ids))[:limit]
    records: dict[str, dict[str, Any]] = {}
    failures: list[dict[str, str]] = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(work_by_id, identifier): identifier for identifier in unique}
        for future in as_completed(futures):
            identifier = futures[future]
            try:
                records[identifier] = compact(future.result())
            except Exception as exc:
                failures.append({"id": identifier, "error": str(exc)})
    return [records[identifier] for identifier in unique if identifier in records], failures


def citing_records(anchor_id: str) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    params = urlencode(
        {
            "filter": f"cites:{anchor_id.rsplit('/', 1)[-1]}",
            "per-page": 100,
            "select": "id,doi,display_name,publication_year,type,cited_by_count,primary_location",
        }
    )
    payload = fetch_json(f"{BASE}/works?{params}")
    return [compact(work) for work in payload.get("results", [])], payload.get("meta", {})


def main() -> None:
    parser = argparse.ArgumentParser(description="Capture one-hop OpenAlex citation neighborhoods.")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    neighborhoods = []
    for doi in ANCHORS:
        anchor_raw = fetch_json(f"{BASE}/works/https://doi.org/{quote(doi, safe='/')}")
        anchor_id = anchor_raw["id"]
        citing, citing_meta = citing_records(anchor_id)
        reference_ids = list(anchor_raw.get("referenced_works") or [])
        related_ids = list(anchor_raw.get("related_works") or [])
        referenced_sample, referenced_failures = related_records(reference_ids, limit=60)
        related, related_failures = related_records(related_ids, limit=30)
        neighborhoods.append(
            {
                "anchor": compact(anchor_raw),
                "anchor_openalex_id": anchor_id,
                "anchor_referenced_work_count": len(reference_ids),
                "anchor_related_work_count": len(related_ids),
                "citing_meta": citing_meta,
                "citing_works": citing,
                "referenced_works_sample": referenced_sample,
                "referenced_works_failures": referenced_failures,
                "related_works": related,
                "related_works_failures": related_failures,
            }
        )

    artifact = {
        "schema": "alg1_replan.openalex_citation_graph.v1",
        "candidate": "I3-CVGR",
        "channel": "CITATION_GRAPH",
        "retrieved_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source_locator": "https://api.openalex.org/works",
        "anchors": list(ANCHORS),
        "neighborhoods": neighborhoods,
        "screening_terms": [
            "constraint graph", "co-violation", "co-occurrence", "community",
            "network", "donor", "recombination", "constraint correlation",
        ],
        "claim_boundary": (
            "The captured one-hop OpenAlex graph is an auditable discovery view, not an exhaustive "
            "citation index or proof of novelty. Missing DOI links and indexing lag remain possible."
        ),
    }
    raw = json.dumps(artifact, ensure_ascii=False, indent=2).encode("utf-8")
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(raw)
    print(
        json.dumps(
            {
                "output": str(output),
                "sha256": hashlib.sha256(raw).hexdigest().upper(),
                "anchors": len(neighborhoods),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()

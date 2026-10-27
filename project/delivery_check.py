"""Check saved evidence and delivery integrity; never train or integrate."""
import csv
import hashlib
import json
from pathlib import Path
import re
import sys
from datetime import datetime

ROOT = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    checks = []
    def check(name, passed):
        checks.append({"check": name, "passed": bool(passed)})

    audit = read(ROOT / "results/audit.json")
    config_hash = sha(ROOT / "config.json")
    data_hash = sha(ROOT / "preflight/prepared.npz")
    physics_hash = sha(ROOT / "physics_run/best.pt")
    check("analysis configuration matches delivery", audit["config_sha256"] == config_hash)
    check("14 saved predictions audited", audit["prediction_rows"] == audit["expected_rows"] == 14)
    check("all predictions finite and metrics recomputed", audit["all_finite"] and all(
        x["finite_predictions"] and x["metric_recomputed"] and x["starts_match"] for x in audit["runs"]))
    check("same-seed independent prediction reproduction", audit["same_seed_reproduction"]["bitwise_equal"])
    check("physical and strict-reproduction boundaries retained", not audit["physical_validation"] and not audit["strict_paper_reproduction"])
    resource = ROOT.parents[1] / "05_evidence/20260928_robot_paper_selection/resources"
    check("raw data source hash", sha(resource / "common_data__py_recording_2021_12_15_20H_45M.mat") == audit["raw_sha256"])
    pm = read(ROOT / "physics_run/manifest.json")
    check("physical artifact and original source snapshot", pm["artifact_complete"] and
          pm["config_sha256"] == config_hash and all(
              sha(ROOT / "physics_run/source" / n) == h for n, h in pm["code_sha256"].items()))
    for item in audit["runs"]:
        dest = ROOT / "runs" / item["run"]
        manifest = read(dest / "manifest.json")
        check(item["run"] + " input and version lineage", manifest["config_sha256"] == config_hash
              and manifest["input_sha256"] == data_hash and manifest["physics_sha256"] == physics_hash
              and all(sha(dest / "source" / n) == h for n, h in manifest["code_sha256"].items()))
        if item["run"] in audit["recovered_exports"]:
            recovery = read(dest / "recovery.json")
            check(item["run"] + " failure retained and recovery traceable", manifest["status"] == "failed"
                  and (dest / "failure.txt").is_file() and (dest / "recovered_metrics.json").is_file()
                  and recovery["source_prediction_sha256"] == sha(dest / "predictions.npz")
                  and not recovery["retrained"] and not recovery["resimulated"])
        else:
            check(item["run"] + " saved result hash", manifest["artifact_complete"]
                  and manifest["prediction_sha256"] == sha(dest / "predictions.npz")
                  and manifest["metrics_sha256"] == sha(dest / "metrics.json"))
    counts = {"coverage": 18, "joint_metrics": 252, "paired_comparisons": 9,
              "run_metrics": 42, "summary": 15, "training_runs": 14, "variable_dictionary": 72}
    for name, expected in counts.items():
        with (ROOT / "results" / (name + ".csv")).open(encoding="utf-8-sig", newline="") as f:
            check(name + " row coverage", len(list(csv.DictReader(f))) == expected)
    rendered = read(ROOT / "results/render_manifest.json")
    check("six figure groups in three formats", len(rendered["figures"]) == 6 and all(
        (ROOT / "results/figures" / Path(n).with_suffix(ext)).is_file()
        and (ROOT / "results/figures" / Path(n).with_suffix(ext)).stat().st_size > 1000
        for n in rendered["figures"] for ext in [".png", ".svg", ".pdf"]))
    for path in [ROOT / "README.md", ROOT / "results/第4步_重跑分析报告.md"]:
        links = re.findall(r"\]\(([^)]+)\)", path.read_text(encoding="utf-8"))
        local = [x for x in links if not x.startswith(("https://", "http://", "#"))]
        check(path.name + " local links resolve", all((path.parent / x).exists() for x in local))
    log = (ROOT / "tests_pass.log").read_text(encoding="utf-8-sig")
    check("11 mathematical and implementation checks", "Ran 11 tests" in log and re.search(r"(?m)^OK\s*$", log))
    inventory = sorted([p for p in ROOT.glob("*.py")] + [ROOT / "config.json", ROOT / "实验协议.md", ROOT / "reproduce.ps1"]
                       + list((ROOT / "results").glob("*.csv")) + list((ROOT / "results/figures").glob("*")))
    output = {"checked_at": datetime.now().astimezone().isoformat(),
              "delivery_integrity_pass": all(x["passed"] for x in checks), "checks": checks,
              "recovered_export_count": len(audit["recovered_exports"]),
              "full_replay_launcher_executed_again": "--from-replay" in sys.argv,
              "scope": "saved evidence and packaging integrity; not scientific superiority, convergence, physical validation, or approval-gate certification",
              "file_sha256": {str(p.relative_to(ROOT)): sha(p) for p in inventory}}
    (ROOT / "delivery_check.json").write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"passed": output["delivery_integrity_pass"], "checks": len(checks),
                      "failed": [x["check"] for x in checks if not x["passed"]]}, ensure_ascii=False))
    if not output["delivery_integrity_pass"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

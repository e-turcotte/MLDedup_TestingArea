#!/usr/bin/env python3
"""
Build a regression dataset for Learning-to-Rank directly from benchmark
throughput logs and dedup_features.csv.

Parses the raw throughput logs under a sweep directory (rank*/throughput_logs/),
computes median throughput per (design, rank, benchmark, parallel_cpus) group,
normalizes to rank 0, and joins with dedup features to produce the final
regression CSV.

Usage (from repo root):
    python3 analysis/build_dataset.py SWEEP_DIR [--features CSV] [-o OUTPUT]

    SWEEP_DIR: directory containing rank*/manifest.txt + rank*/throughput_logs/
               e.g. results/20260410_192340/

Examples:
    python3 analysis/build_dataset.py results/20260410_192340/
    python3 analysis/build_dataset.py results/20260410_192340/ --features data/dedup_features.csv -o data/regression_dataset.csv
"""

import argparse
import csv
import re
import statistics
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

REPO_ROOT = Path(__file__).parent.parent
FEATURES_CSV = REPO_ROOT / "data" / "dedup_features.csv"
OUTPUT_CSV = REPO_ROOT / "data" / "regression_dataset.csv"

# ---------------------------------------------------------------------------
# Log filename regexes
# ---------------------------------------------------------------------------

# Current: ..._mldedup_{design}_r{rank}_{benchmark}_{cpus}_{index}.log
STDOUT_RE_RANKED = re.compile(
    r"^throughput_stdout_mldedup_(.+)_r(\d+)_([a-zA-Z]\w*)_(\d+)_(\d+)\.log$"
)
# Old ranked (with Nt- prefix): ..._mldedup_{design}_r{rank}_{Nt}-{benchmark}_{cpus}_{index}.log
STDOUT_RE_RANKED_NT = re.compile(
    r"^throughput_stdout_mldedup_(.+)_r(\d+)_(\d+t)-(.+)_(\d+)_(\d+)\.log$"
)
# Legacy (no rank infix): ..._mldedup_{design}_{Nt}-{benchmark}_{cpus}_{index}.log
STDOUT_RE_LEGACY = re.compile(
    r"^throughput_stdout_mldedup_(.+)_(\d+t)-(.+)_(\d+)_(\d+)\.log$"
)

CYCLES_RE = re.compile(r"Completed after (\d+) cycles")
ELAPSED_RE = re.compile(r"(\d+):(\d+(?:\.\d+)?)elapsed")

# ---------------------------------------------------------------------------
# Features CSV schema (headerless)
# ---------------------------------------------------------------------------

FEATURES_HEADER = [
    "timestamp", "design", "rank", "dedup_module", "original_ir_size",
    "instance_count", "module_ir_size", "boundary_signal_count",
    "boundary_to_interior_ratio", "edge_count_within", "fraction_design_covered",
]

FEATURE_COLUMNS = [
    "instance_count",
    "module_ir_size",
    "boundary_signal_count",
    "boundary_to_interior_ratio",
    "edge_count_within",
    "fraction_design_covered",
    "original_ir_size",
]

OUTPUT_FIELDS = (
    ["design", "rank", "dedup_module", "benchmark", "parallel_cpus"]
    + FEATURE_COLUMNS
    + ["median_throughput_hz", "baseline_throughput_hz", "relative_speedup"]
)

# ---------------------------------------------------------------------------
# Log parsing
# ---------------------------------------------------------------------------


def parse_elapsed(time_log: Path) -> Optional[float]:
    """Return elapsed wall time in seconds from a throughput_time_*.log file."""
    try:
        text = time_log.read_text()
    except OSError:
        return None
    m = ELAPSED_RE.search(text)
    if not m:
        return None
    minutes = int(m.group(1))
    seconds = float(m.group(2))
    return round(minutes * 60 + seconds, 3)


def parse_cycles(stdout_log: Path) -> Optional[int]:
    """Return cycle count from a throughput_stdout_*.log file."""
    try:
        text = stdout_log.read_text()
    except OSError:
        return None
    m = CYCLES_RE.search(text)
    return int(m.group(1)) if m else None


def parse_rank(manifest: Path) -> Optional[int]:
    """Return rank integer from manifest.txt."""
    try:
        for line in manifest.read_text().splitlines():
            if line.startswith("rank:"):
                return int(line.split(":", 1)[1].strip())
    except (OSError, ValueError):
        pass
    return None


def iter_manifest_paths(sweep_dir: Path) -> List[Path]:
    """Manifests under nested runs or directly under sweep_dir (timestamp folder)."""
    seen: Set[Path] = set()
    out: List[Path] = []
    for pattern in ("*/rank*/manifest.txt", "rank*/manifest.txt"):
        for p in sweep_dir.glob(pattern):
            key = p.resolve()
            if key not in seen:
                seen.add(key)
                out.append(p)
    return sorted(out, key=lambda x: str(x))


def parse_log_filename(name: str) -> Optional[Dict[str, Any]]:
    """Extract (design, benchmark, cpus) from a throughput_stdout log filename."""
    m = STDOUT_RE_RANKED.match(name)
    if m:
        design, _rank_in_name, benchmark, cpus, _idx = m.groups()
        return {"design": design, "benchmark": benchmark, "cpus": int(cpus)}

    m = STDOUT_RE_RANKED_NT.match(name)
    if m:
        design, _rank_in_name, _nt, benchmark, cpus, _idx = m.groups()
        return {"design": design, "benchmark": benchmark, "cpus": int(cpus)}

    m = STDOUT_RE_LEGACY.match(name)
    if m:
        design, _nt, benchmark, cpus, _idx = m.groups()
        return {"design": design, "benchmark": benchmark, "cpus": int(cpus)}

    return None


def collect_sweep_from_logs(
    sweep_dir: Path,
) -> Dict[Tuple[str, int, str, int], List[float]]:
    """Parse throughput logs into (design, rank, benchmark, parallel_cpus) -> [throughput_hz]."""
    groups: Dict[Tuple[str, int, str, int], List[float]] = {}

    for manifest in iter_manifest_paths(sweep_dir):
        rank_dir = manifest.parent
        rank = parse_rank(manifest)
        if rank is None:
            print(f"WARNING: could not parse rank from {manifest}", file=sys.stderr)
            continue

        logs_dir = rank_dir / "throughput_logs"
        if not logs_dir.is_dir():
            print(f"WARNING: no throughput_logs in {rank_dir}", file=sys.stderr)
            continue

        for stdout_log in sorted(logs_dir.glob("throughput_stdout_*.log")):
            parsed = parse_log_filename(stdout_log.name)
            if parsed is None:
                print(f"WARNING: unexpected filename {stdout_log.name}", file=sys.stderr)
                continue

            time_log = logs_dir / stdout_log.name.replace(
                "throughput_stdout_", "throughput_time_"
            )

            cycle_count = parse_cycles(stdout_log)
            wall_time = parse_elapsed(time_log)

            if cycle_count is None:
                print(f"WARNING: no cycle count in {stdout_log}", file=sys.stderr)
                continue
            if wall_time is None:
                print(f"WARNING: no elapsed time in {time_log}", file=sys.stderr)
                continue
            if wall_time <= 0:
                continue

            key = (parsed["design"], rank, parsed["benchmark"], parsed["cpus"])
            groups.setdefault(key, []).append(cycle_count / wall_time)

    return groups


# ---------------------------------------------------------------------------
# Features loading
# ---------------------------------------------------------------------------


def load_features(path: Path) -> Dict[Tuple[str, int], dict]:
    """Load dedup features CSV (headerless) keyed by (design, rank)."""
    features: Dict[Tuple[str, int], dict] = {}
    with path.open(newline="") as f:
        reader = csv.reader(f)
        for raw in reader:
            if len(raw) < len(FEATURES_HEADER):
                print(f"WARNING: skipping short features row: {raw}", file=sys.stderr)
                continue
            row = dict(zip(FEATURES_HEADER, raw))
            try:
                rank = int(row["rank"])
            except ValueError:
                print(f"WARNING: bad rank in features: {row}", file=sys.stderr)
                continue
            design = row["design"].strip()
            features[(design, rank)] = row
    return features


# ---------------------------------------------------------------------------
# Dataset construction
# ---------------------------------------------------------------------------


def build_dataset(
    sweep: Dict[Tuple[str, int, str, int], List[float]],
    features: Dict[Tuple[str, int], dict],
) -> List[dict]:
    baselines: Dict[Tuple[str, str, int], float] = {}
    medians: Dict[Tuple[str, int, str, int], float] = {}

    for (cpu, rank, bench, pcpus), samples in sweep.items():
        med = statistics.median(samples)
        medians[(cpu, rank, bench, pcpus)] = med
        if rank == 0:
            baselines[(cpu, bench, pcpus)] = med

    rows: List[dict] = []
    missing_baseline: set = set()
    missing_features: set = set()

    for (cpu, rank, bench, pcpus), med in sorted(medians.items()):
        if rank == 0:
            continue

        base_key = (cpu, bench, pcpus)
        if base_key not in baselines:
            if base_key not in missing_baseline:
                print(
                    f"WARNING: no rank-0 baseline for {base_key}, skipping",
                    file=sys.stderr,
                )
                missing_baseline.add(base_key)
            continue

        feat_key = (cpu, rank)
        if feat_key not in features:
            if feat_key not in missing_features:
                print(
                    f"WARNING: no features for {feat_key}, skipping",
                    file=sys.stderr,
                )
                missing_features.add(feat_key)
            continue

        feat = features[feat_key]
        baseline = baselines[base_key]
        speedup = med / baseline if baseline > 0 else None

        row = {
            "design": cpu,
            "rank": rank,
            "dedup_module": feat.get("dedup_module", ""),
            "benchmark": bench,
            "parallel_cpus": pcpus,
        }
        for col in FEATURE_COLUMNS:
            row[col] = feat.get(col, "")
        row["median_throughput_hz"] = round(med, 4)
        row["baseline_throughput_hz"] = round(baseline, 4)
        row["relative_speedup"] = round(speedup, 6) if speedup is not None else ""

        rows.append(row)

    return rows


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Build LTR regression dataset from throughput logs + dedup features."
    )
    p.add_argument(
        "sweep_dir",
        type=Path,
        help="Sweep directory containing rank*/manifest.txt (e.g. results/20260410_192340/)",
    )
    p.add_argument(
        "--features", type=Path, default=FEATURES_CSV, help="Dedup features CSV"
    )
    p.add_argument(
        "-o", "--output", type=Path, default=OUTPUT_CSV, help="Output CSV path"
    )
    return p.parse_args()


def main():
    args = parse_args()

    sweep_dir = args.sweep_dir.resolve()
    if not sweep_dir.is_dir():
        print(f"ERROR: sweep directory not found: {sweep_dir}", file=sys.stderr)
        sys.exit(1)
    if not args.features.is_file():
        print(f"ERROR: features CSV not found: {args.features}", file=sys.stderr)
        sys.exit(1)

    print(f"Parsing throughput logs from {sweep_dir} ...", file=sys.stderr)
    sweep = collect_sweep_from_logs(sweep_dir)
    features = load_features(args.features)

    print(
        f"Loaded {len(features)} feature rows, {len(sweep)} sweep groups",
        file=sys.stderr,
    )

    rows = build_dataset(sweep, features)
    if not rows:
        print("ERROR: no rows produced", file=sys.stderr)
        sys.exit(1)

    out = args.output.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=OUTPUT_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} rows to {out}")


if __name__ == "__main__":
    main()

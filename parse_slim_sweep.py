#!/usr/bin/env python3
"""
Parse slim_sweep logs into a labeled CSV for ML input.

Columns: rank_chosen, cpu, benchmark, cycle_count, wall_time_s

Usage:
    python3 parse_slim_sweep.py [SWEEP_DIR]

    Default SWEEP_DIR: <repo>/archive/slim_sweep
    Accepts either layout:
      - SWEEP_DIR/<any>/rank*/manifest.txt   (nested runs)
      - SWEEP_DIR/rank*/manifest.txt         (e.g. all_parallel/20260329_091719/)
"""

import csv
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Set


SWEEP_DIR = Path(__file__).parent / "archive" / "slim_sweep"
OUTPUT_CSV = Path(__file__).parent / "slim_sweep_data.csv"

# Ranked: ..._mldedup_{design}_r{rank}_{Nt}-{benchmark}_{cpus}_{index}.log
STDOUT_RE_RANKED = re.compile(
    r"^throughput_stdout_mldedup_(.+)_r(\d+)_(\d+t)-(.+)_(\d+)_(\d+)\.log$"
)
# Legacy (no rank infix): ..._mldedup_{design}_{Nt}-{benchmark}_{cpus}_{index}.log
STDOUT_RE_LEGACY = re.compile(
    r"^throughput_stdout_mldedup_(.+)_(\d+t)-(.+)_(\d+)_(\d+)\.log$"
)
CYCLES_RE = re.compile(r"Completed after (\d+) cycles")
# time output: "76.69user 0.37system 1:17.07elapsed ..."
# elapsed can be M:SS.SS or H:MM:SS.SS
ELAPSED_RE = re.compile(r"(\d+):(\d+(?:\.\d+)?)elapsed")


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


def collect_rows(sweep_dir: Path) -> List[Dict[str, Any]]:
    rows = []
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
            m = STDOUT_RE_RANKED.match(stdout_log.name)
            if m:
                design, _rank_in_name, _nt, benchmark, _cpus, _idx = m.groups()
            else:
                m = STDOUT_RE_LEGACY.match(stdout_log.name)
                if not m:
                    print(f"WARNING: unexpected filename {stdout_log.name}", file=sys.stderr)
                    continue
                design, _nt, benchmark, _cpus, _idx = m.groups()
            time_log = logs_dir / stdout_log.name.replace("throughput_stdout_", "throughput_time_")

            cycle_count = parse_cycles(stdout_log)
            wall_time = parse_elapsed(time_log)

            if cycle_count is None:
                print(f"WARNING: no cycle count in {stdout_log}", file=sys.stderr)
                continue
            if wall_time is None:
                print(f"WARNING: no elapsed time in {time_log}", file=sys.stderr)
                continue

            rows.append({
                "rank_chosen": rank,
                "cpu": design,
                "benchmark": benchmark,
                "cycle_count": cycle_count,
                "wall_time_s": wall_time,
            })

    return rows


def main():
    sweep_dir = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else SWEEP_DIR
    if not sweep_dir.is_dir():
        print(f"ERROR: sweep directory not found: {sweep_dir}", file=sys.stderr)
        sys.exit(1)

    rows = collect_rows(sweep_dir)
    if not rows:
        print("ERROR: no data parsed", file=sys.stderr)
        sys.exit(1)

    fieldnames = ["rank_chosen", "cpu", "benchmark", "cycle_count", "wall_time_s"]
    with OUTPUT_CSV.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} rows to {OUTPUT_CSV}")


if __name__ == "__main__":
    main()

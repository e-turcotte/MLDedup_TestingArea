#!/usr/bin/env python3
"""
Aggregate MLDedup rank-sweep results into a per-(design, rank) summary.

Usage:
    python3 aggregate_rank_sweep.py <archive_root>

    <archive_root> is the timestamped directory produced by run_mldedup_rank_sweep.sh,
    e.g.  archive/mldedup_rank_sweep/20260320_2300/

    It contains rank1/, rank2/, ... each with:
        throughput_logs/throughput_stdout_mldedup_<design>_<bench>_<ncpus>_<runid>.log
        throughput_logs/throughput_stdout_mldedup_<design>_r<rank>_<bench>_<ncpus>_<runid>.log (rank infix)
        throughput_logs/throughput_time_mldedup_... (same basename pattern as stdout)
        essent_logs/essent_<design>.log or essent_<design>_r<rank>.log

Output:
    - CSV to stdout: design, rank, geo_mean_cycles, geo_mean_elapsed_s, n_datapoints
    - Also writes <archive_root>/summary.csv
"""

import os
import re
import sys
import math
from collections import defaultdict


def parse_cycles(path):
    """Extract cycle count from emulator stdout log."""
    try:
        with open(path) as f:
            for line in f:
                m = re.search(r"Completed after (\d+) cycles", line)
                if m:
                    return int(m.group(1))
    except OSError:
        pass
    return None


def parse_elapsed_seconds(path):
    """Extract elapsed wall time from /usr/bin/time output."""
    try:
        with open(path) as f:
            text = f.read()
    except OSError:
        return None

    # Format: "Mm:SS.xxelapsed" or "SS.xxelapsed"
    m = re.search(r"(?:(\d+):)?(\d+\.\d+)elapsed", text)
    if m:
        minutes = int(m.group(1)) if m.group(1) else 0
        seconds = float(m.group(2))
        return minutes * 60.0 + seconds
    return None


def geometric_mean(values):
    if not values:
        return None
    log_sum = sum(math.log(v) for v in values)
    return math.exp(log_sum / len(values))


def parse_log_filename(name):
    """
    Parse throughput_stdout_mldedup_<design>_<bench>_<ncpus>_<runid>.log
    or throughput_stdout_mldedup_<design>_r<rank>_<bench>_<ncpus>_<runid>.log
    Returns (design, benchmark, ncpus, runid) or None.
    """
    prefix = "throughput_stdout_mldedup_"
    if not name.startswith(prefix) or not name.endswith(".log"):
        return None
    body = name[len(prefix):-len(".log")]

    # Last two segments are <ncpus>_<runid>; everything before is <design>_<bench> or <design>_rK_<bench>
    parts = body.rsplit("_", 2)
    if len(parts) < 3:
        return None
    try:
        ncpus = int(parts[-2])
        runid = int(parts[-1])
    except ValueError:
        return None

    design_bench = parts[0]

    # Split design from benchmark: benchmark always starts with "<digit>t-"
    m = re.search(r"_(\d+t-.+)$", design_bench)
    if not m:
        return None
    bench = m.group(1)
    design_raw = design_bench[: m.start()]

    rm = re.match(r"^(.+)_r(\d+)$", design_raw)
    if rm:
        design = rm.group(1)
    else:
        design = design_raw

    return design, bench, ncpus, runid


def check_clamped_ranks(archive_root, ranks):
    """Warn if multiple ranks chose the same module for a design (rank clamping)."""
    rank_modules = {}
    for rank in ranks:
        essent_dir = os.path.join(archive_root, f"rank{rank}", "essent_logs")
        if not os.path.isdir(essent_dir):
            continue
        for fname in os.listdir(essent_dir):
            if not fname.startswith("essent_") or not fname.endswith(".log"):
                continue
            m = re.match(r"^essent_(.+)_r\d+\.log$", fname)
            if m:
                design = m.group(1)
            else:
                design = fname[len("essent_"):-len(".log")]
            path = os.path.join(essent_dir, fname)
            try:
                with open(path) as f:
                    text = f.read()
            except OSError:
                continue
            m = re.search(r"Deduplicate module \[(\S+)\]", text)
            mod = m.group(1) if m else "(none/no-dedup)"
            rank_modules.setdefault(design, {})[rank] = mod

    for design, rmap in sorted(rank_modules.items()):
        mods = list(rmap.values())
        unique = set(mods)
        if len(unique) < len(mods):
            dups = [(r, m) for r, m in sorted(rmap.items())]
            print(f"# WARNING: {design}: some ranks chose the same module (clamped?): {dups}",
                  file=sys.stderr)


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <archive_root>", file=sys.stderr)
        sys.exit(1)

    archive_root = sys.argv[1]
    if not os.path.isdir(archive_root):
        print(f"ERROR: not a directory: {archive_root}", file=sys.stderr)
        sys.exit(1)

    rank_dirs = sorted(
        [d for d in os.listdir(archive_root) if re.match(r"rank\d+$", d)],
        key=lambda d: int(d[4:]),
    )
    if not rank_dirs:
        print(f"ERROR: no rank*/ subdirectories in {archive_root}", file=sys.stderr)
        sys.exit(1)

    ranks = [int(d[4:]) for d in rank_dirs]
    check_clamped_ranks(archive_root, ranks)

    # (design, rank) -> {"cycles": [...], "elapsed": [...]}
    data = defaultdict(lambda: {"cycles": [], "elapsed": []})

    for rank_dir_name in rank_dirs:
        rank = int(rank_dir_name[4:])
        logs_dir = os.path.join(archive_root, rank_dir_name, "throughput_logs")
        if not os.path.isdir(logs_dir):
            print(f"# WARNING: missing {logs_dir}", file=sys.stderr)
            continue

        for fname in sorted(os.listdir(logs_dir)):
            parsed = parse_log_filename(fname)
            if parsed is None:
                continue
            design, bench, ncpus, runid = parsed

            stdout_path = os.path.join(logs_dir, fname)
            time_fname = fname.replace("throughput_stdout_", "throughput_time_")
            time_path = os.path.join(logs_dir, time_fname)

            cycles = parse_cycles(stdout_path)
            elapsed = parse_elapsed_seconds(time_path)

            key = (design, rank)
            if cycles is not None and cycles > 0:
                data[key]["cycles"].append(cycles)
            if elapsed is not None and elapsed > 0:
                data[key]["elapsed"].append(elapsed)

    header = "design,rank,geo_mean_cycles,geo_mean_elapsed_s,n_datapoints"
    lines = [header]

    for (design, rank) in sorted(data.keys()):
        entry = data[(design, rank)]
        gm_cycles = geometric_mean(entry["cycles"])
        gm_elapsed = geometric_mean(entry["elapsed"])
        n = min(len(entry["cycles"]), len(entry["elapsed"]))
        cycles_str = f"{gm_cycles:.1f}" if gm_cycles else ""
        elapsed_str = f"{gm_elapsed:.2f}" if gm_elapsed else ""
        lines.append(f"{design},{rank},{cycles_str},{elapsed_str},{n}")

    output = "\n".join(lines) + "\n"
    print(output, end="")

    summary_path = os.path.join(archive_root, "summary.csv")
    with open(summary_path, "w") as f:
        f.write(output)
    print(f"# Written to {summary_path}", file=sys.stderr)


if __name__ == "__main__":
    main()

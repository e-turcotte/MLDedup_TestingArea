#!/usr/bin/env python3
"""
Plot rank (x) vs mean throughput kHz (y), one line per design.

Throughput = cycle_count / wall_time_s (shown as kHz). Multiple benchmarks -> one subplot each
(vertical stack); line hue differs per benchmark, designs differ by shade/marker. Optional --benchmark
filters to a single subplot. Optional --cpu plots one design only (focus on rank).

Examples:
  python3 analysis/plot_rank_throughput.py --csv data/throughput_data.csv -o all.pdf
  python3 analysis/plot_rank_throughput.py --csv data/throughput_data.csv --benchmark qsort -o qsort.pdf
  python3 analysis/plot_rank_throughput.py --csv data/throughput_data.csv --cpu boom21-2large -o one_cpu.pdf
  python3 analysis/plot_rank_throughput.py --csv data/throughput_data.csv --max-rank 10 -o ranks_1_10.pdf

By default only ranks 1-5 are included (--min-rank 1 --max-rank 5).
"""

import argparse
import colorsys
import csv
import statistics
import sys
from collections import defaultdict
from pathlib import Path
from typing import DefaultDict, Dict, List, Optional, Sequence, Tuple

import matplotlib as mpl
import matplotlib.pyplot as plt

mpl.rcParams["pdf.fonttype"] = 42
mpl.rcParams["ps.fonttype"] = 42

MARKERS = ("o", "s", "^", "v", "D", "P", "X", "*", "h", "8")

# Throughput in CSV is cycles/s; axis shows kcycles/s (kHz).
HZ_TO_KHZ = 1e3


def load_rows(csv_path: Path) -> List[dict]:
    rows: List[dict] = []
    with csv_path.open(newline="") as f:
        reader = csv.DictReader(f)
        expected = {"rank_chosen", "cpu", "benchmark", "cycle_count", "wall_time_s"}
        if reader.fieldnames is None or not expected.issubset(set(reader.fieldnames)):
            missing = expected - set(reader.fieldnames or [])
            raise SystemExit(f"CSV missing columns: {sorted(missing)}")
        for raw in reader:
            try:
                rank = int(raw["rank_chosen"])
                cycles = int(raw["cycle_count"])
                wall = float(raw["wall_time_s"])
            except (TypeError, ValueError) as e:
                print(f"WARNING: skip row (bad number): {raw!r} ({e})", file=sys.stderr)
                continue
            if wall <= 0:
                print(f"WARNING: skip row (wall_time_s<=0): {raw!r}", file=sys.stderr)
                continue
            rows.append(
                {
                    "rank_chosen": rank,
                    "cpu": raw["cpu"].strip(),
                    "benchmark": raw["benchmark"].strip(),
                    "throughput_hz": cycles / wall,
                }
            )
    if not rows:
        raise SystemExit("No valid rows after parsing.")
    return rows


def bucket_throughputs(
    rows: Sequence[dict], benchmark: str
) -> DefaultDict[Tuple[int, str], List[float]]:
    """Map (rank, cpu) -> list of throughput samples for this benchmark."""
    buckets: DefaultDict[Tuple[int, str], List[float]] = defaultdict(list)
    for r in rows:
        if r["benchmark"] != benchmark:
            continue
        buckets[(r["rank_chosen"], r["cpu"])].append(r["throughput_hz"])
    return buckets


def series_for_cpu(
    buckets: DefaultDict[Tuple[int, str], List[float]], cpu: str
) -> Tuple[List[int], List[float]]:
    ranks = sorted(r for (r, c) in buckets if c == cpu)
    means = [statistics.mean(buckets[(rank, cpu)]) for rank in ranks]
    return ranks, means


def pct_diff_lowest_to_highest(values: Sequence[float]) -> Optional[float]:
    """Percent by which the maximum exceeds the minimum: 100 * (max - min) / min."""
    if not values:
        return None
    lo, hi = min(values), max(values)
    if lo <= 0:
        return None
    return 100.0 * (hi - lo) / lo


def cpu_markers(global_cpus: Sequence[str]) -> Dict[str, str]:
    return {cpu: MARKERS[i % len(MARKERS)] for i, cpu in enumerate(global_cpus)}


def line_rgb_panel_cpu(panel_idx: int, cpu_idx: int, n_cpus: int) -> Tuple[float, float, float]:
    """Hue from panel (benchmark); saturation/value vary across CPUs in that panel."""
    hue = (panel_idx * 0.27 + 0.04) % 1.0
    if n_cpus <= 1:
        return colorsys.hsv_to_rgb(hue, 0.72, 0.85)
    t = cpu_idx / (n_cpus - 1)
    sat = 0.55 + 0.38 * (1.0 - 0.4 * t)
    val = 0.38 + 0.52 * t
    return colorsys.hsv_to_rgb(hue, sat, val)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--csv", type=Path, required=True, help="Slim sweep CSV path")
    p.add_argument(
        "--benchmark",
        type=str,
        default=None,
        help="Plot only this benchmark (single subplot).",
    )
    p.add_argument(
        "--cpu",
        type=str,
        default=None,
        help="Plot only this CPU (one line per subplot; y-scale focuses on that design).",
    )
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Output figure path (.pdf, .png, .svg). Default: <csv_stem>_rank_throughput.pdf next to CSV.",
    )
    p.add_argument(
        "--min-rank",
        type=int,
        default=1,
        help="Include only rank_chosen >= this value (default: 1).",
    )
    p.add_argument(
        "--max-rank",
        type=int,
        default=5,
        help="Include only rank_chosen <= this value (default: 5).",
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()
    csv_path = args.csv.resolve()
    if not csv_path.is_file():
        raise SystemExit(f"CSV not found: {csv_path}")

    if args.min_rank > args.max_rank:
        raise SystemExit("--min-rank must be <= --max-rank")

    rows = load_rows(csv_path)
    rows = [
        r
        for r in rows
        if args.min_rank <= r["rank_chosen"] <= args.max_rank
    ]
    if not rows:
        raise SystemExit(
            f"No rows with rank_chosen in [{args.min_rank}, {args.max_rank}]."
        )

    all_cpus = sorted({r["cpu"] for r in rows})

    if args.cpu is not None:
        if args.cpu not in all_cpus:
            raise SystemExit(f"Unknown CPU {args.cpu!r}. Available: {all_cpus}")
        rows = [r for r in rows if r["cpu"] == args.cpu]
        if not rows:
            raise SystemExit(f"No rows left after --cpu {args.cpu!r}.")

    benchmarks = sorted({r["benchmark"] for r in rows})

    if args.benchmark is not None:
        if args.benchmark not in benchmarks:
            raise SystemExit(
                f"Unknown benchmark {args.benchmark!r}. Available: {benchmarks}"
            )
        benchmarks_to_plot = [args.benchmark]
    else:
        benchmarks_to_plot = benchmarks

    if args.benchmark:
        scope_rows = [r for r in rows if r["benchmark"] == args.benchmark]
    else:
        scope_rows = list(rows)
    global_cpus = sorted({r["cpu"] for r in scope_rows})
    if not global_cpus:
        raise SystemExit("No CPU column values in scoped data.")

    markers = cpu_markers(global_cpus)
    n_cpus = len(global_cpus)
    n_panels = len(benchmarks_to_plot)
    fig_h = max(4.0, 3.8 * n_panels)
    fig, axes = plt.subplots(n_panels, 1, figsize=(10, fig_h), sharex=True)
    if n_panels == 1:
        axes = [axes]

    for panel_idx, (ax, bench) in enumerate(zip(axes, benchmarks_to_plot)):
        buckets = bucket_throughputs(rows, bench)
        panel_khz: List[float] = []
        for cpu_idx, cpu in enumerate(global_cpus):
            ranks, means = series_for_cpu(buckets, cpu)
            if not ranks:
                continue
            means_khz = [m / HZ_TO_KHZ for m in means]
            panel_khz.extend(means_khz)
            rgb = line_rgb_panel_cpu(panel_idx, cpu_idx, n_cpus)
            ax.plot(
                ranks,
                means_khz,
                color=rgb,
                marker=markers[cpu],
                linestyle="-",
                label=cpu,
            )
        spread = pct_diff_lowest_to_highest(panel_khz)
        if spread is not None:
            blurb = f"{spread:.1f}% difference between lowest and highest throughput"
            ax.text(
                0.98,
                0.97,
                blurb,
                transform=ax.transAxes,
                ha="right",
                va="top",
                fontsize=8,
                bbox={
                    "boxstyle": "round,pad=0.35",
                    "facecolor": "white",
                    "edgecolor": "0.5",
                    "alpha": 0.92,
                },
            )
        title = f"Mean Throughput for Concurrent Runs Executing {bench}"
        if args.cpu:
            title = f"{title} ({args.cpu})"
        ax.set_title(title)
        ax.set_ylabel("Throughput (kHz)")
        ax.grid(True, alpha=0.4)
        ax.set_xticks(list(range(args.min_rank, args.max_rank + 1)))
        ax.set_xlabel("Selected Deduplicated Module's Rank")
        ax.tick_params(axis="x", labelbottom=True)

    legend_rect = (0, 0.07, 1.0, 1.0)
    if len(global_cpus) > 1:
        if n_panels == 1:
            handles, labels = axes[0].get_legend_handles_labels()
            fig.legend(
                handles,
                labels,
                loc="upper left",
                bbox_to_anchor=(1.02, 1.0),
                borderaxespad=0,
                fontsize=9,
            )
            legend_rect = (0, 0.07, 0.82, 1.0)
        else:
            for ax in axes:
                ax.legend(loc="upper left", fontsize=8, framealpha=0.92)

    fig.text(
        0.5,
        0.02,
        r"Throughput is simulated cycles per real elapsed second; vertical axis is in kHz ($10^3$ cycles/s).",
        ha="center",
        va="bottom",
        fontsize=9,
        style="italic",
        transform=fig.transFigure,
    )
    fig.tight_layout(rect=legend_rect)

    out = args.output
    if out is None:
        stem = csv_path.stem
        if args.cpu:
            stem = f"{stem}_{args.cpu}"
        out = csv_path.with_name(f"{stem}_rank_throughput.pdf")
    else:
        out = out.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, bbox_inches="tight")
    print(f"Wrote {out}", file=sys.stderr)


if __name__ == "__main__":
    main()

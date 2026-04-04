#!/usr/bin/env bash
#
# Run throughput benchmarks using pre-built ranked emulators (see compile_emulators.sh).
# For each rank, sets MLDEDUP_ESSENT_RANK and runs measure_throughput.py once.
#
# Run from MLDedup_TestingArea/.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
SYSML="$(cd "$SCRIPT_DIR/.." && pwd)"
JAR_DIR="$SYSML/jars"
ESSENT_MLDEDUP="$SCRIPT_DIR/essent-mldedup"

usage() {
    echo "Usage: $0 --benchmarks NAMES [--parallel-cpus LIST] [--min-rank K] [--max-rank K]"
    echo "          [--designs CSV] [--archive DIR] [--max-concurrent N]"
    echo ""
    echo "  --benchmarks     Comma-separated short names (vvadd, memcpy, matmul, …)"
    echo "  --parallel-cpus   Comma-separated ints (default: 12)"
    echo "  --min-rank/--max-rank  Inclusive rank range matching essent-<k>.jar / emulator names (default 0..10)"
    echo "  --designs         Comma-separated designs (default: slim six)"
    echo "  --archive         If set, copy logs + manifest under DIR/<timestamp>/rank<k>/"
    echo "  --max-concurrent  MEASURE_MAX_CONCURRENT_RUNS (default 1)"
    exit 1
}

BENCHMARKS=""
PARALLEL_CPUS="12"
MIN_RANK="0"
MAX_RANK="10"
DESIGNS_CSV=""
ARCHIVE=""
MAX_CONCURRENT="1"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --benchmarks) BENCHMARKS="${2:-}"; shift 2 ;;
        --parallel-cpus) PARALLEL_CPUS="${2:-}"; shift 2 ;;
        --min-rank) MIN_RANK="${2:-}"; shift 2 ;;
        --max-rank) MAX_RANK="${2:-}"; shift 2 ;;
        --designs) DESIGNS_CSV="${2:-}"; shift 2 ;;
        --archive) ARCHIVE="${2:-}"; shift 2 ;;
        --max-concurrent) MAX_CONCURRENT="${2:-}"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

[[ -n "$BENCHMARKS" ]] || { echo "ERROR: --benchmarks is required"; usage; }

if ! [[ "$MIN_RANK" =~ ^[0-9]+$ ]] || ! [[ "$MAX_RANK" =~ ^[0-9]+$ ]]; then
    echo "ERROR: ranks must be non-negative integers"
    exit 1
fi
(( MAX_RANK < MIN_RANK )) && { echo "ERROR: --max-rank must be >= --min-rank"; exit 1; }

if [[ -z "$DESIGNS_CSV" ]]; then
    DESIGNS_CSV="rocket21-1c,rocket21-2c,boom21-small,boom21-2small,boom21-large,boom21-2large"
fi

for k in $(seq "$MIN_RANK" "$MAX_RANK"); do
    JAR="$JAR_DIR/essent-${k}.jar"
    if [[ ! -f "$JAR" ]]; then
        echo "ERROR: jar not found (needed to document run): $JAR"
        exit 1
    fi
    shopt -s nullglob
    _rank_bins=( "$ESSENT_MLDEDUP/emulator/emulator_essent_"*_r"${k}" )
    shopt -u nullglob
    if (( ${#_rank_bins[@]} == 0 )); then
        echo "ERROR: no ranked emulators found for rank $k (expected $ESSENT_MLDEDUP/emulator/emulator_essent_<design>_r${k})"
        echo "Run ./compile_emulators.sh first."
        exit 1
    fi
done
unset _rank_bins

export MLDEDUP_ONLY_THROUGHPUT=1
export MLDEDUP_SLIM_SWEEP=1
export MLDEDUP_BENCHMARK_NAMES="$BENCHMARKS"
export MLDEDUP_PARALLEL_CPUS="$PARALLEL_CPUS"
export MLDEDUP_TEST_DESIGNS="$DESIGNS_CSV"
export MEASURE_MAX_CONCURRENT_RUNS="$MAX_CONCURRENT"

if [[ ! -d "$SCRIPT_DIR/mt-benchmarks" ]]; then
    echo "ERROR: mt-benchmarks directory missing in $SCRIPT_DIR"
    exit 1
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_ROOT=""
if [[ -n "$ARCHIVE" ]]; then
    ARCHIVE_ROOT="$ARCHIVE/$TIMESTAMP"
    mkdir -p "$ARCHIVE_ROOT"
fi

echo "=== run_benchmarks ==="
echo "    Ranks:      $MIN_RANK..$MAX_RANK"
echo "    Designs:    $DESIGNS_CSV"
echo "    Benchmarks: $MLDEDUP_BENCHMARK_NAMES"
echo "    Host par:   $MLDEDUP_PARALLEL_CPUS"
if [[ -n "$ARCHIVE_ROOT" ]]; then
    echo "    Archive:    $ARCHIVE_ROOT"
fi
echo ""

for k in $(seq "$MIN_RANK" "$MAX_RANK"); do
    JAR="$JAR_DIR/essent-${k}.jar"
    export MLDEDUP_ESSENT_RANK="$k"
    echo "=== Rank $k (MLDEDUP_ESSENT_RANK=$k) ==="
    rm -rf log/throughput_stdout_* log/throughput_time_* log/throughput.log 2>/dev/null || true
    python3 measure_throughput.py

    if [[ -n "$ARCHIVE_ROOT" ]]; then
        RANK_ARCHIVE="$ARCHIVE_ROOT/rank${k}"
        mkdir -p "$RANK_ARCHIVE/throughput_logs"
        cp -a log/throughput_stdout_* log/throughput_time_* "$RANK_ARCHIVE/throughput_logs/" 2>/dev/null || true
        cp log/throughput.log "$RANK_ARCHIVE/" 2>/dev/null || true
        mkdir -p "$RANK_ARCHIVE/essent_logs"
        IFS=',' read -r -a _ds <<< "$DESIGNS_CSV"
        for d in "${_ds[@]}"; do
            d="${d// /}"
            [[ -n "$d" ]] || continue
            if [[ -f "$ESSENT_MLDEDUP/log/essent_${d}_r${k}.log" ]]; then
                cp "$ESSENT_MLDEDUP/log/essent_${d}_r${k}.log" "$RANK_ARCHIVE/essent_logs/" 2>/dev/null || true
            elif [[ -f "$ESSENT_MLDEDUP/log/essent_${d}.log" ]]; then
                cp "$ESSENT_MLDEDUP/log/essent_${d}.log" "$RANK_ARCHIVE/essent_logs/" 2>/dev/null || true
            fi
        done
        {
            echo "rank: $k"
            echo "jar: $JAR"
            echo "timestamp: $(date -Iseconds)"
            echo "designs: ${DESIGNS_CSV//,/ }"
            echo "MLDEDUP_BENCHMARK_NAMES: $MLDEDUP_BENCHMARK_NAMES"
            echo "MLDEDUP_PARALLEL_CPUS: $MLDEDUP_PARALLEL_CPUS"
            echo "MEASURE_MAX_CONCURRENT_RUNS: $MEASURE_MAX_CONCURRENT_RUNS"
            if command -v sha256sum &>/dev/null; then
                echo "jar_sha256: $(sha256sum "$JAR" | awk '{print $1}')"
            fi
        } > "$RANK_ARCHIVE/manifest.txt"
        echo "  Archived to $RANK_ARCHIVE"
    fi
done

unset MLDEDUP_ESSENT_RANK

echo ""
echo "=== run_benchmarks complete ==="

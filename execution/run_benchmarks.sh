#!/usr/bin/env bash
#
# Run throughput benchmarks using pre-built ranked emulators (see compile_emulators.sh).
# Default mode: for each rank, sets MLDEDUP_ESSENT_RANK and runs
# measure_throughput.py once across every design in DESIGNS.
#
# Pipelined mode (--pipeline): walks (rank, design) pairs in lockstep with
# compile_emulators.sh — for each (rank, design) it polls the corresponding
# emulator_essent_<design>_r<rank> binary, then runs measure_throughput.py
# scoped to that single design. The wait stops if compile_emulators.sh
# writes its completion sentinel ($ESSENT_MLDEDUP/log/compile_complete.flag)
# without producing the binary; that (design, rank) is then skipped.
#
# Run from MLDedup_TestingArea/.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
SYSML="$(cd "$REPO_ROOT/.." && pwd)"
JAR_DIR="$REPO_ROOT/jars"
ESSENT_MLDEDUP="$REPO_ROOT/essent-mldedup"

usage() {
    echo "Usage: $0 --benchmarks NAMES [--parallel-cpus LIST] [--ranks LIST]"
    echo "          [--designs CSV] [--archive DIR] [--max-concurrent N]"
    echo "          [--pipeline] [--poll-interval SEC] [--wait-timeout SEC]"
    echo ""
    echo "  --benchmarks     Comma-separated short names (vvadd, multiply, memcpy, mm, qsort, spmv, rsort, dhrystone, median, towers)"
    echo "  --parallel-cpus  Comma-separated ints (default: 12)"
    echo "  --ranks          Comma-separated rank suffixes matching emulator_essent_<design>_r<rank> (default: ml,1,0)"
    echo "  --designs        Comma-separated designs (default: all 16 compiled designs)"
    echo "  --archive        If set, copy logs + manifest under DIR/<timestamp>/rank<k>/"
    echo "  --max-concurrent MEASURE_MAX_CONCURRENT_RUNS (default 1)"
    echo "  --pipeline       Run benchmarks in lockstep with a concurrent compile_emulators.sh:"
    echo "                   wait per (design, rank) for the emulator binary, then run benchmarks"
    echo "                   scoped to that design. Skips items if compile finishes without them."
    echo "  --poll-interval  Seconds between binary-existence polls in --pipeline mode (default: 5)"
    echo "  --wait-timeout   Max seconds to wait for any single emulator before erroring out in"
    echo "                   --pipeline mode (default: 14400 = 4h). Use 0 to wait indefinitely."
    exit 1
}

BENCHMARKS=""
PARALLEL_CPUS="12"
RANKS_CSV="ml,1,0"
DESIGNS_CSV=""
ARCHIVE=""
MAX_CONCURRENT="1"
PIPELINE=0
POLL_INTERVAL="${POLL_INTERVAL:-5}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-14400}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --benchmarks) BENCHMARKS="${2:-}"; shift 2 ;;
        --parallel-cpus) PARALLEL_CPUS="${2:-}"; shift 2 ;;
        --ranks) RANKS_CSV="${2:-}"; shift 2 ;;
        --designs) DESIGNS_CSV="${2:-}"; shift 2 ;;
        --archive) ARCHIVE="${2:-}"; shift 2 ;;
        --max-concurrent) MAX_CONCURRENT="${2:-}"; shift 2 ;;
        --pipeline) PIPELINE=1; shift ;;
        --poll-interval) POLL_INTERVAL="${2:-}"; shift 2 ;;
        --wait-timeout) WAIT_TIMEOUT="${2:-}"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if ! [[ "$POLL_INTERVAL" =~ ^[0-9]+$ ]] || (( POLL_INTERVAL < 1 )); then
    echo "ERROR: --poll-interval must be a positive integer (got: $POLL_INTERVAL)"
    exit 1
fi
if ! [[ "$WAIT_TIMEOUT" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --wait-timeout must be a non-negative integer (got: $WAIT_TIMEOUT)"
    exit 1
fi

[[ -n "$BENCHMARKS" ]] || { echo "ERROR: --benchmarks is required"; usage; }

IFS=',' read -r -a RANKS <<< "$RANKS_CSV"
if (( ${#RANKS[@]} == 0 )); then
    echo "ERROR: --ranks produced an empty list"
    exit 1
fi

if [[ -z "$DESIGNS_CSV" ]]; then
    DESIGNS_CSV="rocket21-1c,rocket21-2c,rocket21-4c,rocket21-6c,rocket21-8c,boom21-small,boom21-2small,boom21-4small,boom21-6small,boom21-8small,boom21-large,boom21-2large,boom21-4large,boom21-mega,boom21-2mega,boom21-4mega"
fi

for k in "${RANKS[@]}"; do
    JAR="$JAR_DIR/essent-${k}.jar"
    if [[ ! -f "$JAR" ]]; then
        echo "ERROR: jar not found (needed to document run): $JAR"
        exit 1
    fi
    if (( PIPELINE == 0 )); then
        # In non-pipelined mode the emulators must already exist before we
        # start. In --pipeline mode the binaries may show up as we go, so we
        # skip this check (wait_for_emu enforces presence per item).
        shopt -s nullglob
        _rank_bins=( "$ESSENT_MLDEDUP/emulator/emulator_essent_"*_r"${k}" )
        shopt -u nullglob
        if (( ${#_rank_bins[@]} == 0 )); then
            echo "ERROR: no ranked emulators found for rank $k (expected $ESSENT_MLDEDUP/emulator/emulator_essent_<design>_r${k})"
            echo "Run ./compilation/compile_emulators.sh first, or pass --pipeline to overlap."
            exit 1
        fi
    fi
done
unset _rank_bins 2>/dev/null || true

# In --pipeline mode, wait for a single (design, rank) emulator binary to
# show up. Returns 0 once it exists, 1 if compile_emulators.sh finished
# without producing it (sentinel present but binary missing) or if we hit
# the wait-timeout.
COMPILE_SENTINEL="$ESSENT_MLDEDUP/log/compile_complete.flag"
wait_for_emu() {
    local d="$1" k="$2"
    local emu="$ESSENT_MLDEDUP/emulator/emulator_essent_${d}_r${k}"
    local start_ts; start_ts=$(date +%s)
    local announced=0
    while [[ ! -f "$emu" ]]; do
        if [[ -f "$COMPILE_SENTINEL" ]]; then
            echo "  WARN: compile finished without producing emulator_essent_${d}_r${k} — skipping"
            return 1
        fi
        if (( WAIT_TIMEOUT > 0 )); then
            local elapsed=$(( $(date +%s) - start_ts ))
            if (( elapsed > WAIT_TIMEOUT )); then
                echo "  ERROR: timed out (>${WAIT_TIMEOUT}s) waiting for emulator_essent_${d}_r${k}" >&2
                return 1
            fi
        fi
        if (( announced == 0 )); then
            echo "  waiting for emulator_essent_${d}_r${k} (poll every ${POLL_INTERVAL}s) ..."
            announced=1
        fi
        sleep "$POLL_INTERVAL"
    done
    return 0
}

export MLDEDUP_ONLY_THROUGHPUT=1
export MLDEDUP_SLIM_SWEEP=1
export MLDEDUP_BENCHMARK_NAMES="$BENCHMARKS"
export MLDEDUP_PARALLEL_CPUS="$PARALLEL_CPUS"
export MLDEDUP_TEST_DESIGNS="$DESIGNS_CSV"
export MEASURE_MAX_CONCURRENT_RUNS="$MAX_CONCURRENT"

if [[ ! -d "$REPO_ROOT/mt-benchmarks" ]]; then
    echo "ERROR: mt-benchmarks directory missing in $REPO_ROOT"
    exit 1
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_ROOT=""
if [[ -n "$ARCHIVE" ]]; then
    ARCHIVE_ROOT="$ARCHIVE/$TIMESTAMP"
    mkdir -p "$ARCHIVE_ROOT"
fi

# DESIGNS_CSV is the canonical list. We also build an array form for the
# pipelined per-design loop below; both stay in sync.
IFS=',' read -r -a DESIGNS_ARR <<< "$DESIGNS_CSV"
# Strip whitespace and drop empty entries.
_clean_designs=()
for _d in "${DESIGNS_ARR[@]}"; do
    _d="${_d// /}"
    [[ -n "$_d" ]] && _clean_designs+=("$_d")
done
DESIGNS_ARR=("${_clean_designs[@]}")
unset _clean_designs _d

echo "=== run_benchmarks ==="
echo "    Mode:       $([[ $PIPELINE -eq 1 ]] && echo "pipelined (per-design, waits on compile sentinel)" || echo "monolithic (one measure_throughput.py per rank)")"
echo "    Ranks:      ${RANKS[*]}"
echo "    Designs:    $DESIGNS_CSV"
echo "    Benchmarks: $MLDEDUP_BENCHMARK_NAMES"
echo "    Host par:   $MLDEDUP_PARALLEL_CPUS"
if (( PIPELINE == 1 )); then
    echo "    Sentinel:   $COMPILE_SENTINEL"
    echo "    Polling:    every ${POLL_INTERVAL}s, timeout $([[ $WAIT_TIMEOUT -eq 0 ]] && echo "(none)" || echo "${WAIT_TIMEOUT}s")"
fi
if [[ -n "$ARCHIVE_ROOT" ]]; then
    echo "    Archive:    $ARCHIVE_ROOT"
fi
echo ""

for k in "${RANKS[@]}"; do
    JAR="$JAR_DIR/essent-${k}.jar"
    export MLDEDUP_ESSENT_RANK="$k"
    echo "=== Rank $k (MLDEDUP_ESSENT_RANK=$k) ==="
    rm -rf log/throughput_stdout_* log/throughput_time_* log/throughput.log 2>/dev/null || true

    if (( PIPELINE == 1 )); then
        # Per-(design, rank) loop: wait for the binary, then benchmark just
        # that one design. measure_throughput.py respects MLDEDUP_TEST_DESIGNS
        # as a CSV filter, so passing a single design narrows it correctly.
        for d in "${DESIGNS_ARR[@]}"; do
            if ! wait_for_emu "$d" "$k"; then
                continue
            fi
            echo "  benchmark ${d} r${k}"
            export MLDEDUP_TEST_DESIGNS="$d"
            python3 execution/measure_throughput.py
        done
        # Restore the canonical CSV so anything downstream (archive block,
        # next rank iteration) sees the full list again.
        export MLDEDUP_TEST_DESIGNS="$DESIGNS_CSV"
    else
        python3 execution/measure_throughput.py
    fi

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

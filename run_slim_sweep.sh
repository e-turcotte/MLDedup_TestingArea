#!/usr/bin/env bash
#
# Slim rank sweep: prepare once, then for each rank compile N designs with essent-{k}.jar
# and run measure_throughput.py with a configurable subset of benchmarks and host-parallelism.
#
# Requires settings.py support: MLDEDUP_SLIM_SWEEP=1 reads:
#   MLDEDUP_BENCHMARK_NAMES  — comma-separated short names (vvadd, memcpy, ...); default: vvadd
#   MLDEDUP_PARALLEL_CPUS    — comma-separated ints (host copies per run); default: 12
#
# Run from MLDedup_TestingArea/.
#
# Env overrides:
#   MIN_RANK              First rank to run (default: 1). Use e.g. MIN_RANK=2 after rank 1 is done.
#   MAX_RANK              Last rank to run (default: 5). Ranks MIN_RANK..MAX_RANK inclusive.
#   PARALLEL              Total thread budget to spread across concurrent design builds (default: nproc).
#                         Each make uses: make -j $((PARALLEL / DESIGN_PARALLEL)) (minimum 1).
#   DESIGN_PARALLEL       Max concurrent prepare_* / compile_essent_* invocations (default: number of designs).
#                         On a 64-thread machine, defaults fan out all designs with ~10 jobs each (when 6 designs).
#                         On a small box, set DESIGN_PARALLEL=1 to run one design at a time with make -j$PARALLEL.
#   MEASURE_MAX_CONCURRENT_RUNS  (default: 1; raise cautiously — overlaps with heavy make/CPU use)
#   MLDEDUP_BENCHMARK_NAMES / BENCHMARKS   (BENCHMARKS is alias for export)
#   MLDEDUP_PARALLEL_CPUS / PARALLEL_CPUS
#
# Example — defaults (vvadd @ 12-way host parallel, 6 designs, 5 ranks):
#   ./run_slim_sweep.sh
#
# Example — multi-benchmark / multi-parallelism:
#   BENCHMARKS=vvadd,memcpy MLDEDUP_PARALLEL_CPUS=1,4,12 ./run_slim_sweep.sh
#
# Example — only ranks 2–5 (skip rank 1 prepare/compile/measure for that sweep):
#   MIN_RANK=2 MAX_RANK=5 ./run_slim_sweep.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
SYSML="$(cd "$SCRIPT_DIR/.." && pwd)"

JAR_DIR="$SYSML/jars"
ESSENT_MLDEDUP="$SCRIPT_DIR/essent-mldedup"
MIN_RANK="${MIN_RANK:-1}"
MAX_RANK="${MAX_RANK:-5}"
PARALLEL="${PARALLEL:-$(nproc)}"
MAX_CONCURRENT="${MEASURE_MAX_CONCURRENT_RUNS:-1}"

# Default experiment: Rocket 1/2c, Boom small/large 1/2c
DESIGNS=(
    rocket21-1c rocket21-2c
    boom21-small boom21-2small
    boom21-large boom21-2large
)
NUM_DESIGNS=${#DESIGNS[@]}
# Concurrent make targets (prepare_*/compile_essent_*); cap to number of designs
DESIGN_PARALLEL="${DESIGN_PARALLEL:-$NUM_DESIGNS}"
(( DESIGN_PARALLEL < 1 )) && DESIGN_PARALLEL=1
(( DESIGN_PARALLEL > NUM_DESIGNS )) && DESIGN_PARALLEL="$NUM_DESIGNS"
JOBS_PER_DESIGN=$(( PARALLEL / DESIGN_PARALLEL ))
(( JOBS_PER_DESIGN < 1 )) && JOBS_PER_DESIGN=1

DESIGNS_CSV="$(IFS=,; echo "${DESIGNS[*]}")"

# Run up to DESIGN_PARALLEL make subprocesses; each does make -jJOBS_PER_DESIGN <target> (optional ESSENT_JAR=)
parallel_make_designs() {
    local mk_prefix=$1
    local jar_opt=${2:-}
    local count=0
    for d in "${DESIGNS[@]}"; do
        echo "  ${mk_prefix}_${d} ..."
        (
            cd "$ESSENT_MLDEDUP"
            if [[ -n "$jar_opt" ]]; then
                make -j"$JOBS_PER_DESIGN" "${mk_prefix}_${d}" "ESSENT_JAR=$jar_opt"
            else
                make -j"$JOBS_PER_DESIGN" "${mk_prefix}_${d}"
            fi
        ) &
        ((++count % DESIGN_PARALLEL == 0)) && wait
    done
    wait
}

# Throughput matrix (passed to Python; see settings.get_throughput_settings)
export MLDEDUP_BENCHMARK_NAMES="${BENCHMARKS:-${MLDEDUP_BENCHMARK_NAMES:-vvadd}}"
export MLDEDUP_PARALLEL_CPUS="${PARALLEL_CPUS:-${MLDEDUP_PARALLEL_CPUS:-12}}"
export MEASURE_MAX_CONCURRENT_RUNS="$MAX_CONCURRENT"

if ! [[ "$MIN_RANK" =~ ^[0-9]+$ ]] || ! [[ "$MAX_RANK" =~ ^[0-9]+$ ]]; then
    echo "ERROR: MIN_RANK and MAX_RANK must be non-negative integers (got MIN_RANK=$MIN_RANK MAX_RANK=$MAX_RANK)"
    exit 1
fi
(( MIN_RANK < 1 )) && { echo "ERROR: MIN_RANK must be >= 1 (got $MIN_RANK)"; exit 1; }
(( MAX_RANK < MIN_RANK )) && { echo "ERROR: MAX_RANK must be >= MIN_RANK (got MIN_RANK=$MIN_RANK MAX_RANK=$MAX_RANK)"; exit 1; }

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_ROOT="$SCRIPT_DIR/archive/slim_sweep/$TIMESTAMP"

echo "=== Slim sweep ==="
echo "    Ranks:      $MIN_RANK..$MAX_RANK  (jars: $JAR_DIR/essent-${MIN_RANK}.jar … essent-${MAX_RANK}.jar)"
echo "    Designs:    ${DESIGNS[*]}"
echo "    make:       PARALLEL=$PARALLEL DESIGN_PARALLEL=$DESIGN_PARALLEL → make -j$JOBS_PER_DESIGN per design"
echo "    Benchmarks: $MLDEDUP_BENCHMARK_NAMES"
echo "    Host par:   $MLDEDUP_PARALLEL_CPUS"
echo "    Archive:    $ARCHIVE_ROOT"
echo ""

# Preflight: jars for the ranks we will run
for k in $(seq "$MIN_RANK" "$MAX_RANK"); do
    JAR="$JAR_DIR/essent-${k}.jar"
    if [[ ! -f "$JAR" ]]; then
        echo "ERROR: jar not found: $JAR"
        echo "Build: cd $SYSML && MAX_RANK=$MAX_RANK ./build_essent_jars.sh"
        exit 1
    fi
done

if [[ ! -d "$SCRIPT_DIR/mt-benchmarks" ]]; then
    echo "ERROR: mt-benchmarks directory not found in $SCRIPT_DIR"
    exit 1
fi

# Prepare once
echo "=== Step 1: Prepare designs ==="
mkdir -p "$ESSENT_MLDEDUP/emulator" "$ESSENT_MLDEDUP/log"
parallel_make_designs prepare
cd "$SCRIPT_DIR"

# Per-rank: compile + throughput + archive
for k in $(seq "$MIN_RANK" "$MAX_RANK"); do
    JAR="$JAR_DIR/essent-${k}.jar"
    RANK_ARCHIVE="$ARCHIVE_ROOT/rank${k}"
    mkdir -p "$RANK_ARCHIVE"

    echo ""
    echo "=== Rank $k: compile with $JAR ==="
    parallel_make_designs compile_essent "$JAR"
    cd "$SCRIPT_DIR"

    rm -rf log/throughput_stdout_* log/throughput_time_* log/throughput.log 2>/dev/null || true

    echo "=== Rank $k: measure_throughput.py ==="
    MLDEDUP_ONLY_THROUGHPUT=1 \
    MLDEDUP_SLIM_SWEEP=1 \
    MLDEDUP_TEST_DESIGNS="$DESIGNS_CSV" \
        python3 measure_throughput.py

    echo "=== Rank $k: archive ==="
    mkdir -p "$RANK_ARCHIVE/throughput_logs"
    cp -a log/throughput_stdout_* log/throughput_time_* "$RANK_ARCHIVE/throughput_logs/" 2>/dev/null || true
    cp log/throughput.log "$RANK_ARCHIVE/" 2>/dev/null || true

    mkdir -p "$RANK_ARCHIVE/essent_logs"
    for d in "${DESIGNS[@]}"; do
        cp "$ESSENT_MLDEDUP/log/essent_${d}.log" "$RANK_ARCHIVE/essent_logs/" 2>/dev/null || true
    done

    {
        echo "rank: $k"
        echo "jar: $JAR"
        echo "timestamp: $(date -Iseconds)"
        echo "designs: ${DESIGNS[*]}"
        echo "MLDEDUP_BENCHMARK_NAMES: $MLDEDUP_BENCHMARK_NAMES"
        echo "MLDEDUP_PARALLEL_CPUS: $MLDEDUP_PARALLEL_CPUS"
        echo "MEASURE_MAX_CONCURRENT_RUNS: $MEASURE_MAX_CONCURRENT_RUNS"
        echo "PARALLEL: $PARALLEL"
        echo "DESIGN_PARALLEL: $DESIGN_PARALLEL"
        echo "JOBS_PER_DESIGN: $JOBS_PER_DESIGN"
        if command -v sha256sum &>/dev/null; then
            echo "jar_sha256: $(sha256sum "$JAR" | awk '{print $1}')"
        fi
    } > "$RANK_ARCHIVE/manifest.txt"

    echo "  Archived to $RANK_ARCHIVE"
done

echo ""
echo "=== Slim sweep complete ==="
echo "Archive root: $ARCHIVE_ROOT"

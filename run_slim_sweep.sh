#!/usr/bin/env bash
#
# Legacy entry point: runs compile_emulators.sh then run_benchmarks.sh in one go.
# For large sweeps, prefer running those scripts separately so benchmarks can reuse
# the 66 emulators without recompiling.
#
# Same env as before (MIN_RANK, MAX_RANK, PARALLEL, DESIGN_PARALLEL, BENCHMARKS /
# MLDEDUP_BENCHMARK_NAMES, PARALLEL_CPUS / MLDEDUP_PARALLEL_CPUS,
# MEASURE_MAX_CONCURRENT_RUNS). Optional: DESIGNS as space-separated list to match
# compile_emulators.sh (default: slim six).
#
# Jar note: build_essent_jars.sh builds essent-1.jar … only; for rank 0 add
# essent-0.jar yourself or set MIN_RANK=1.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MIN_RANK="${MIN_RANK:-0}"
MAX_RANK="${MAX_RANK:-5}"
PARALLEL="${PARALLEL:-$(nproc)}"
DESIGN_PARALLEL="${DESIGN_PARALLEL:-}"
BENCHMARKS="${BENCHMARKS:-${MLDEDUP_BENCHMARK_NAMES:-vvadd}}"
PARALLEL_CPUS="${PARALLEL_CPUS:-${MLDEDUP_PARALLEL_CPUS:-12}}"
MAX_CONCURRENT="${MEASURE_MAX_CONCURRENT_RUNS:-1}"

_dspec="${DESIGNS-}"
if [[ -n "$_dspec" ]]; then
    read -r -a DESIGNS <<< "$_dspec"
else
    DESIGNS=(
        rocket21-1c rocket21-2c
        boom21-small boom21-2small
        boom21-large boom21-2large
    )
fi
unset _dspec

DESIGNS_CSV="$(IFS=,; echo "${DESIGNS[*]}")"
export DESIGNS="${DESIGNS[*]}"

export MIN_RANK MAX_RANK PARALLEL
[[ -n "$DESIGN_PARALLEL" ]] && export DESIGN_PARALLEL

echo "=== run_slim_sweep (wrapper) → compile_emulators.sh ==="
"$SCRIPT_DIR/compile_emulators.sh"

echo ""
echo "=== run_slim_sweep (wrapper) → run_benchmarks.sh ==="
exec "$SCRIPT_DIR/run_benchmarks.sh" \
    --benchmarks "$BENCHMARKS" \
    --parallel-cpus "$PARALLEL_CPUS" \
    --min-rank "$MIN_RANK" \
    --max-rank "$MAX_RANK" \
    --designs "$DESIGNS_CSV" \
    --archive "$SCRIPT_DIR/archive/slim_sweep" \
    --max-concurrent "$MAX_CONCURRENT"

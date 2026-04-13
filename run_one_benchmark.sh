#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

EMU_DIR=essent-mldedup/emulator
BENCH_DIR=mt-benchmarks

declare -A CORES=(
    [rocket21-1c]=1
    [rocket21-2c]=2
    [boom21-small]=1
    [boom21-2small]=2
    [boom21-large]=1
    [boom21-2large]=2
)

BENCHMARK=""
RANK="${RANK:-0}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --benchmark) BENCHMARK="${2:-}"; shift 2 ;;
        --rank)      RANK="${2:-}"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 --benchmark <name> [--rank K]"
            echo ""
            echo "Available benchmarks (exact name without .riscv):"
            ls -1 "$BENCH_DIR/bin-1t/" | sed 's/\.riscv$//'  | sed 's/^/  /'
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

[[ -n "$BENCHMARK" ]] || { echo "ERROR: --benchmark is required (try --help)"; exit 1; }

for design in rocket21-1c rocket21-2c boom21-small boom21-2small boom21-large boom21-2large; do
    emu="$EMU_DIR/emulator_essent_${design}_r${RANK}"
    nc=${CORES[$design]}

    bench="$BENCH_DIR/bin-${nc}t/${BENCHMARK}.riscv"

    if [[ ! -f "$bench" ]]; then
        echo "SKIP $design (no ${BENCHMARK}.riscv in bin-${nc}t/)"
        continue
    fi

    if [[ ! -x "$emu" ]]; then
        echo "SKIP $design (missing $emu)"
        continue
    fi

    echo "=== $design (${nc}t: $(basename "$bench")) ==="
    if "$emu" "$bench"; then
        echo "  PASS"
    else
        echo "  FAIL (exit code $?)"
    fi
    echo ""
done

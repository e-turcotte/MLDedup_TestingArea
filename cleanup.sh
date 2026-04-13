#!/usr/bin/env bash
# Remove temporary files, build artifacts, and emulators from MLDedup_TestingArea.
# Optionally remove riscv-isa-sim clones so prepare re-clones later.
# Run from MLDedup_TestingArea or pass its path as first argument.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Optional: set CLEAN_RISCV_ISA_SIM=1 to also remove riscv-isa-sim (prepare will re-clone).
CLEAN_RISCV_ISA_SIM="${CLEAN_RISCV_ISA_SIM:-0}"
if [[ "$1" == "--all" ]] || [[ "$1" == "-a" ]]; then
    CLEAN_RISCV_ISA_SIM=1
    shift
fi

echo "=== Cleaning temp and log ==="
rm -rf temp/* log/*

echo "=== Cleaning essent-master build and emulator ==="
rm -rf essent-master/build
rm -rf essent-master/emulator/*

echo "=== Cleaning essent-mldedup build and emulator ==="
rm -rf essent-mldedup/build
rm -rf essent-mldedup/emulator/*

if [[ "$CLEAN_RISCV_ISA_SIM" == "1" ]]; then
    echo "=== Removing riscv-isa-sim clones (prepare will re-clone) ==="
    rm -rf essent-master/rocket21-*/riscv-isa-sim
    rm -rf essent-mldedup/rocket21-*/riscv-isa-sim
else
    echo "=== Skipping riscv-isa-sim (use CLEAN_RISCV_ISA_SIM=1 or ./cleanup.sh --all to remove) ==="
fi

echo "=== Done ==="

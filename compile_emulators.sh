#!/usr/bin/env bash
#
# Build all ranked MLDedup emulators: for each rank k and each design, produce
#   essent-mldedup/emulator/emulator_essent_<design>_r<k>
# (plus essent logs under essent-mldedup/log/).
#
# Run from MLDedup_TestingArea/.
#
# Jar files (SysML/jars/essent-<k>.jar):
#   build_essent_jars.sh builds essent-1.jar … essent-MAX_RANK.jar only (no rank 0).
#   For rank 0, supply essent-0.jar yourself (e.g. cp MLDedup/utils/bin/essent.jar jars/essent-0.jar),
#   or set MIN_RANK=1 and MAX_RANK=10 to use jars 1..10 only.
#
# Env:
#   MIN_RANK, MAX_RANK     — inclusive rank range (default 0..10)
#   DESIGNS                — space-separated design names (default: slim sweep six).
#                            Example: DESIGNS="rocket21-1c boom21-small" ./compile_emulators.sh
#   PARALLEL, DESIGN_PARALLEL — thread fan-out (same semantics as run_slim_sweep.sh)
#   SKIP_SUBMOD=1          — do not run submod.sh mldedup
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
SYSML="$(cd "$SCRIPT_DIR/.." && pwd)"
JAR_DIR="$SYSML/jars"
ESSENT_MLDEDUP="$SCRIPT_DIR/essent-mldedup"
SUBMOD_SH="$SCRIPT_DIR/submod.sh"

MIN_RANK="${MIN_RANK:-0}"
MAX_RANK="${MAX_RANK:-10}"
PARALLEL="${PARALLEL:-$(nproc)}"
SKIP_SUBMOD="${SKIP_SUBMOD:-0}"

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

NUM_DESIGNS=${#DESIGNS[@]}
DESIGN_PARALLEL="${DESIGN_PARALLEL:-$NUM_DESIGNS}"
(( DESIGN_PARALLEL < 1 )) && DESIGN_PARALLEL=1
(( DESIGN_PARALLEL > NUM_DESIGNS )) && DESIGN_PARALLEL="$NUM_DESIGNS"
JOBS_PER_DESIGN=$(( PARALLEL / DESIGN_PARALLEL ))
(( JOBS_PER_DESIGN < 1 )) && JOBS_PER_DESIGN=1

if ! [[ "$MIN_RANK" =~ ^[0-9]+$ ]] || ! [[ "$MAX_RANK" =~ ^[0-9]+$ ]]; then
    echo "ERROR: MIN_RANK and MAX_RANK must be non-negative integers"
    exit 1
fi
(( MAX_RANK < MIN_RANK )) && { echo "ERROR: MAX_RANK must be >= MIN_RANK"; exit 1; }

parallel_make_designs() {
    local mk_prefix=$1
    shift
    local -a extra_make_args=("$@")
    local -a pids=()
    local -a names=()
    local failed=0

    _flush_wait() {
        for i in "${!pids[@]}"; do
            wait "${pids[$i]}" || { echo "ERROR: ${names[$i]} failed" >&2; ((++failed)); }
        done
        pids=(); names=()
    }

    for d in "${DESIGNS[@]}"; do
        echo "  ${mk_prefix}_${d} ..."
        (
            cd "$ESSENT_MLDEDUP"
            make -j"$JOBS_PER_DESIGN" "${mk_prefix}_${d}" "${extra_make_args[@]}"
        ) &
        pids+=($!)
        names+=("${mk_prefix}_${d}")
        (( ${#pids[@]} >= DESIGN_PARALLEL )) && _flush_wait
    done
    _flush_wait
    (( failed == 0 ))
}

echo "=== compile_emulators ==="
echo "    Ranks:     $MIN_RANK..$MAX_RANK  (jars: $JAR_DIR/essent-${MIN_RANK}.jar … essent-${MAX_RANK}.jar)"
echo "    Designs:   ${DESIGNS[*]}"
echo "    make:      PARALLEL=$PARALLEL DESIGN_PARALLEL=$DESIGN_PARALLEL → make -j$JOBS_PER_DESIGN per design"
echo ""

for k in $(seq "$MIN_RANK" "$MAX_RANK"); do
    JAR="$JAR_DIR/essent-${k}.jar"
    if [[ ! -f "$JAR" ]]; then
        echo "ERROR: jar not found: $JAR"
        echo "Build jars: cd $SYSML && ./build_essent_jars.sh"
        echo "Note: build_essent_jars.sh starts at essent-1.jar; for rank 0 copy a baseline jar to essent-0.jar."
        exit 1
    fi
done

if [[ "$SKIP_SUBMOD" != "1" ]]; then
    if [[ ! -x "$SUBMOD_SH" ]]; then
        echo "ERROR: submod.sh not found or not executable: $SUBMOD_SH"
        exit 1
    fi
    echo "=== Spike / riscv-isa-sim (submod.sh mldedup) ==="
    bash "$SUBMOD_SH" mldedup
fi

mkdir -p "$ESSENT_MLDEDUP/emulator" "$ESSENT_MLDEDUP/log"

echo "=== Prepare designs (once) ==="
parallel_make_designs prepare

for d in "${DESIGNS[@]}"; do
    if [[ ! -d "$ESSENT_MLDEDUP/build/$d" ]]; then
        echo "ERROR: prepare failed for design $d — missing $ESSENT_MLDEDUP/build/$d"
        exit 1
    fi
done

for k in $(seq "$MIN_RANK" "$MAX_RANK"); do
    JAR="$JAR_DIR/essent-${k}.jar"
    echo ""
    echo "=== Compile rank $k ($JAR) ==="
    parallel_make_designs compile_essent "ESSENT_JAR=$JAR" "ESSENT_RANK=$k"
done

echo ""
echo "=== Merging per-run dedup feature CSVs ==="
COMBINED="$ESSENT_MLDEDUP/log/dedup_features_all.csv"
FIRST_CSV="$(ls "$ESSENT_MLDEDUP/log"/dedup_features_*.csv 2>/dev/null | head -1)"
if [[ -n "$FIRST_CSV" ]]; then
    head -1 "$FIRST_CSV" > "$COMBINED"
    for f in "$ESSENT_MLDEDUP/log"/dedup_features_*.csv; do
        tail -n +2 "$f" >> "$COMBINED"
    done
    echo "Combined features CSV: $COMBINED ($(tail -n +2 "$COMBINED" | wc -l) data rows)"
else
    echo "WARNING: no dedup_features_*.csv files found in $ESSENT_MLDEDUP/log/"
fi

echo ""
echo "=== compile_emulators complete ==="
echo "Binaries under $ESSENT_MLDEDUP/emulator/ matching emulator_essent_*_r<rank>"

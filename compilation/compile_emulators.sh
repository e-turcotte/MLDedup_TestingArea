#!/usr/bin/env bash
#
# Build all ranked MLDedup emulators: for each rank k and each design, produce
#   essent-mldedup/emulator/emulator_essent_<design>_r<k>
# (plus essent logs under essent-mldedup/log/).
#
# Run from MLDedup_TestingArea/.
#
# Jar files live under SysML/jars/ (JAR_DIR). build_essent_jars.sh builds essent-1.jar …;
# supply essent-0.jar yourself if needed (e.g. cp …/essent.jar jars/essent-0.jar).
#
# Env:
#   ESSENT_JAR_STEPS       — space-separated jar:rankSuffix entries (default: essent-0, essent-1, essent-ml).
#                            Example: ESSENT_JAR_STEPS="essent-0.jar:0 essent-1.jar:1 essent-ml.jar:ml"
#                            Produces emulator_essent_<design>_r0, _r1, _rml.
#   ESSENT_RANK_SWEEP=1    — ignore ESSENT_JAR_STEPS; use MIN_RANK..MAX_RANK with essent-<k>.jar
#   MIN_RANK, MAX_RANK     — used only when ESSENT_RANK_SWEEP=1 (default 0..10)
#   ESSENT_ONLY_JAR        — if set, single-jar mode (overrides ESSENT_JAR_STEPS and rank sweep).
#                            Example: ESSENT_ONLY_JAR=essent-ml.jar ESSENT_ONLY_RANK=ml ./compile_emulators.sh
#   ESSENT_ONLY_RANK       — suffix for single-jar mode (default: ml)
#   DESIGNS                — space-separated design names (see default array below).
#                            Example: DESIGNS="rocket21-1c boom21-small" ./compile_emulators.sh
#   PARALLEL, DESIGN_PARALLEL — thread fan-out for parallel design builds.
#   SKIP_SUBMOD=1          — do not run clone_spike.sh mldedup
#   HEARTBEAT_INTERVAL     — seconds between "still in flight" prints during a
#                            wave (default: 60). 0 disables.
#   CLEAN=1                — ignore existing outputs; re-run all prepare and
#                            compile steps regardless of what already exists.
#
# ESSENT_EXTRA_ARGS handling:
#   compile_essent_for_jar auto-sets ESSENT_EXTRA_ARGS=--ml-rank whenever the
#   jar basename is `essent-ml.jar`, so the ML model takes the dedup decision
#   instead of the heuristic. Per-design Makefile-emulator.mk forwards it to
#   the `java essent.Driver` invocation. When ESSENT_RANK_SWEEP=1 we also
#   append one extra `_rml` pass after the integer rank loop (if
#   essent-ml.jar exists), so a single sweep produces both the heuristic
#   ranks and the ML pick.
#
# Compiler / optimization (single-tier, all designs identical):
#   ESSENT_CXX             — g++ used for every design's host emulator.
#                            If unset, auto-detects the newest gcc-toolset g++
#                            on the host (gcc-toolset-{14,13,12,11}); falls
#                            back to whatever `g++` is on PATH. RHEL 8's
#                            system g++ 8.5.0 SIGSEGVs in cc1plus on the giant
#                            generated TestHarness.h files (recursive parser
#                            blows the stack), so the toolset g++ matters
#                            for boom21-* designs.
#   All designs build with the same opt flags (whatever the per-design
#   Makefile-emulator.mk default is, typically -O3). For experiments that
#   compare throughput across designs, mixing -O levels skews the host-side
#   sim_cycles/sec measurement and is therefore avoided here.
#
# DEPRECATED env vars (parsed for back-compat, no longer have any effect):
#   HEAVY_DESIGNS, HEAVY_OPT_FLAGS, HEAVY_DESIGN_PARALLEL, HEAVY_CXX. The
#   prior heavy-tier mechanism applied -O1 + a serialized wave to a hand-
#   picked subset of boom designs to avoid OOM on smaller hosts; on a fat
#   build host this serialization just slows things down, and the -O1
#   mismatch makes cross-design throughput comparisons invalid.
#
# All-ranks-parallel scheduling (ALL_RANKS_PARALLEL=1):
#   By default we run one wave per jar (e.g. all 16 designs at rank ml, then
#   all 16 at rank 1, then all 16 at rank 0). With ALL_RANKS_PARALLEL=1 the
#   16 × 3 = 48 (design, rank) pairs are fanned out into a single wave so
#   every (design, rank) make-tree races concurrently — useful on fat hosts
#   (EPYC w/ 100+ cores and 1 TiB+ RAM). Job dispatch order is ML-first
#   (left-to-right through ESSENT_JAR_STEPS), so when the concurrency cap is
#   below 48, the first ML batch grabs the slots and finishes first; this in
#   turn lets a `run_benchmarks.sh --pipeline` consumer start measuring the
#   _rml binaries earlier. The wave concurrency cap defaults to "all jobs"
#   (NJOBS); cap it via DESIGN_PARALLEL=<jobs> if RAM is tight (each job
#   peaks at ~10–30 GiB during cc1plus on the boom designs). Only effective
#   in the default ESSENT_JAR_STEPS path; ESSENT_ONLY_JAR / ESSENT_RANK_SWEEP
#   keep their original wave-per-jar behavior.
#
# Pipelining with run_benchmarks.sh:
#   On exit (success OR failure), this script writes a sentinel file
#       $ESSENT_MLDEDUP/log/compile_complete.flag
#   from its EXIT/INT/TERM trap, with `rc=<exit_code>` in the body. A
#   pipelined consumer (run_benchmarks.sh --pipeline) polls for individual
#   emulator binaries and uses this sentinel solely to know when the
#   producer has stopped, so it can give up on any binaries that never
#   materialised. The flag is removed at the start of each run so a stale
#   sentinel from a crashed prior run does not confuse the consumer.
#
set -euo pipefail
# Enable job control so each backgrounded job runs in its own process group;
# this lets us SIGTERM a whole make-tree (java + g++ + cc1plus) at once via
# `kill -- -<pid>` if a sibling fails.
set -m

# Bump the stack size for child processes. The system's default 8 MiB stack
# is too small for cc1plus on the giant auto-generated TestHarness.h files
# (the recursive parser / SSA passes blow the stack and SIGSEGV with
# "internal compiler error: Segmentation fault signal terminated program
# cc1plus" even at -O1, with no memory pressure). `unlimited` (or a generous
# fixed cap) reliably prevents the front-end stack overflow path.
if ulimit -s unlimited 2>/dev/null; then
    :
else
    ulimit -s 524288 2>/dev/null || true   # 512 MiB fallback
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
SYSML="$(cd "$REPO_ROOT/.." && pwd)"
JAR_DIR="$REPO_ROOT/jars"
ESSENT_MLDEDUP="$REPO_ROOT/essent-mldedup"
SUBMOD_SH="$REPO_ROOT/compilation/clone_spike.sh"

MIN_RANK="${MIN_RANK:-0}"
MAX_RANK="${MAX_RANK:-10}"
PARALLEL="${PARALLEL:-$(nproc)}"
SKIP_SUBMOD="${SKIP_SUBMOD:-0}"
# Single-jar mode: set ESSENT_ONLY_JAR to a filename in JAR_DIR or an absolute path.
ESSENT_ONLY_JAR="${ESSENT_ONLY_JAR-}"
ESSENT_ONLY_RANK="${ESSENT_ONLY_RANK:-ml}"
# Multi-jar plan: "jarfile:rankSuffix" … (rankSuffix becomes _r<suffix> on binaries). Default = three-way compare.
ESSENT_JAR_STEPS="${ESSENT_JAR_STEPS:-essent-ml.jar:ml essent-1.jar:1 essent-0.jar:0}"
ESSENT_RANK_SWEEP="${ESSENT_RANK_SWEEP:-0}"

HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-60}"
CLEAN="${CLEAN:-0}"

# When 1, fan out all (design × jar) pairs into one giant wave instead of
# running one wave per jar. ML jobs are dispatched first so they grab the
# concurrency slots and finish first when the cap is below NJOBS. See top-of-
# file docstring. Only effective in the default ESSENT_JAR_STEPS path.
ALL_RANKS_PARALLEL="${ALL_RANKS_PARALLEL:-0}"

# Pipelining sentinel — see top-of-file docstring. Single file, written from
# the EXIT trap so the consumer cannot deadlock on producer crashes/SIGINT.
COMPILE_COMPLETE_FLAG="$ESSENT_MLDEDUP/log/compile_complete.flag"

# Compiler selection (single-tier — same g++ for every design).
#
# ESSENT_CXX, if unset, auto-detects the newest available gcc-toolset g++.
# RHEL 8's system g++ 8.5.0 SIGSEGVs (cc1plus stack overflow) on the giant
# auto-generated TestHarness.h headers from boom21-{4,2}{mega,large}; gcc
# 13/14 from gcc-toolset-{13,14} handles them fine.
ESSENT_CXX="${ESSENT_CXX-}"
if [[ -z "$ESSENT_CXX" ]]; then
    for _gcc_candidate in \
        /opt/rh/gcc-toolset-14/root/usr/bin/g++ \
        /opt/rh/gcc-toolset-13/root/usr/bin/g++ \
        /opt/rh/gcc-toolset-12/root/usr/bin/g++ \
        /opt/rh/gcc-toolset-11/root/usr/bin/g++; do
        if [[ -x "$_gcc_candidate" ]]; then
            ESSENT_CXX="$_gcc_candidate"
            break
        fi
    done
    unset _gcc_candidate
fi

# Deprecated env vars from the prior two-tier model. Parsed silently for
# back-compat (so existing wrapper scripts don't error) but no longer have
# any effect — see the top-of-file docstring.
: "${HEAVY_DESIGNS-}" "${HEAVY_OPT_FLAGS-}" "${HEAVY_DESIGN_PARALLEL-}" "${HEAVY_CXX-}"

_dspec="${DESIGNS-}"
if [[ -n "$_dspec" ]]; then
    read -r -a DESIGNS <<< "$_dspec"
else
    DESIGNS=(
        rocket21-1c
        rocket21-2c
        rocket21-4c
        rocket21-6c
        rocket21-8c
        boom21-small
        boom21-2small
        boom21-4small
        boom21-6small
        boom21-8small
        boom21-large
        boom21-2large
        boom21-4large
        boom21-mega
        boom21-2mega
        boom21-4mega
    )
fi
unset _dspec

NUM_DESIGNS=${#DESIGNS[@]}
DESIGN_PARALLEL="${DESIGN_PARALLEL:-$NUM_DESIGNS}"
(( DESIGN_PARALLEL < 1 )) && DESIGN_PARALLEL=1
(( DESIGN_PARALLEL > NUM_DESIGNS )) && DESIGN_PARALLEL="$NUM_DESIGNS"
JOBS_PER_DESIGN=$(( PARALLEL / DESIGN_PARALLEL ))
(( JOBS_PER_DESIGN < 1 )) && JOBS_PER_DESIGN=1

_resolve_jar_path() {
    local j="$1"
    if [[ "$j" == */* ]]; then
        printf '%s' "$j"
    else
        printf '%s' "$JAR_DIR/$j"
    fi
}

_is_prepared() {
    [[ "$CLEAN" == "1" ]] && return 1
    [[ -f "$ESSENT_MLDEDUP/build/$1/riscv/lib/libfesvr.a" ]]
}

_is_compiled() {
    [[ "$CLEAN" == "1" ]] && return 1
    [[ -f "$ESSENT_MLDEDUP/emulator/emulator_essent_${1}_r${2}" ]]
}

if [[ -z "$ESSENT_ONLY_JAR" ]] && [[ "$ESSENT_RANK_SWEEP" == "1" ]]; then
    if ! [[ "$MIN_RANK" =~ ^[0-9]+$ ]] || ! [[ "$MAX_RANK" =~ ^[0-9]+$ ]]; then
        echo "ERROR: MIN_RANK and MAX_RANK must be non-negative integers"
        exit 1
    fi
    (( MAX_RANK < MIN_RANK )) && { echo "ERROR: MAX_RANK must be >= MIN_RANK"; exit 1; }
fi

# ---------------------------------------------------------------------------
# Wave runner: launch up to <par> backgrounded `make <mk_prefix>_<design>`
# jobs at once. On the first non-zero exit, send SIGTERM to every remaining
# peer's process group, wait for them, and return non-zero (so the script
# stops launching any further work).
#
# Inputs:
#   $1               concurrency (par)
#   $2               make prefix (e.g. compile_essent, prepare)
#   $3..             extra make args (forwarded verbatim)
#   RUN_DESIGNS[@]   designs to run in this wave (read from caller scope)
# ---------------------------------------------------------------------------
declare -A WAVE_PID2NAME=()
declare -A WAVE_PID2START=()
HEARTBEAT_PID=""

_start_heartbeat() {
    [[ -z "${HEARTBEAT_INTERVAL:-}" ]] && return
    (( HEARTBEAT_INTERVAL <= 0 )) && return
    local hb_state="$HB_STATE_FILE"
    local hb_interval="$HEARTBEAT_INTERVAL"
    (
        # HB_STATE_FILE has one tab-separated line per in-flight job:
        #   <name>\t<start_epoch>
        # We recompute elapsed each tick so the displayed age actually grows.
        while sleep "$hb_interval"; do
            if [[ -s "$hb_state" ]]; then
                local now active=() name start elapsed
                now=$(date +%s)
                while IFS=$'\t' read -r name start; do
                    [[ -z "$name" ]] && continue
                    elapsed=$(( now - start ))
                    active+=("${name}(${elapsed}s)")
                done < "$hb_state"
                if (( ${#active[@]} > 0 )); then
                    printf '[%s heartbeat] in flight (%d): %s\n' \
                        "$(date '+%H:%M:%S')" "${#active[@]}" "${active[*]}" >&2
                fi
            fi
        done
    ) &
    HEARTBEAT_PID=$!
}

_stop_heartbeat() {
    if [[ -n "$HEARTBEAT_PID" ]]; then
        kill "$HEARTBEAT_PID" 2>/dev/null || true
        wait "$HEARTBEAT_PID" 2>/dev/null || true
        HEARTBEAT_PID=""
    fi
}

_refresh_hb_state() {
    local p
    : > "$HB_STATE_FILE"
    for p in "${!WAVE_PID2NAME[@]}"; do
        printf '%s\t%s\n' "${WAVE_PID2NAME[$p]}" "${WAVE_PID2START[$p]}" >> "$HB_STATE_FILE"
    done
}

_kill_wave_peers() {
    local p
    for p in "${!WAVE_PID2NAME[@]}"; do
        # Negative pid → kill the entire process group (java/g++/cc1plus tree)
        kill -- -"$p" 2>/dev/null || kill "$p" 2>/dev/null || true
    done
    # Reap them so we don't leak zombies. Don't propagate their non-zero
    # status — we already know we're failing.
    for p in "${!WAVE_PID2NAME[@]}"; do
        wait "$p" 2>/dev/null || true
    done
    WAVE_PID2NAME=()
    WAVE_PID2START=()
    : > "$HB_STATE_FILE"
}

run_make_wave() {
    local par="$1"; shift
    local mk_prefix="$1"; shift
    local -a extra=("$@")
    local n="${#RUN_DESIGNS[@]}"
    local idx=0

    WAVE_PID2NAME=()
    WAVE_PID2START=()
    : > "$HB_STATE_FILE"
    _start_heartbeat

    _launch_one() {
        local d="$1"
        echo "  ${mk_prefix}_${d} ..."
        (
            cd "$ESSENT_MLDEDUP"
            exec make -j"$JOBS_PER_DESIGN" "${mk_prefix}_${d}" "${extra[@]}"
        ) &
        local pid=$!
        WAVE_PID2NAME[$pid]="${mk_prefix}_${d}"
        WAVE_PID2START[$pid]=$(date +%s)
    }

    while (( idx < n )) && (( ${#WAVE_PID2NAME[@]} < par )); do
        _launch_one "${RUN_DESIGNS[$idx]}"
        idx=$(( idx + 1 ))
    done
    _refresh_hb_state

    while (( ${#WAVE_PID2NAME[@]} > 0 )); do
        local status=0
        # `wait -n` blocks until ANY child terminates and returns its status.
        # Bash 4.3+. We then locate which tracked PID is actually gone.
        wait -n 2>/dev/null || status=$?
        local finished=""
        local p
        for p in "${!WAVE_PID2NAME[@]}"; do
            if ! kill -0 "$p" 2>/dev/null; then
                finished="$p"
                break
            fi
        done
        if [[ -z "$finished" ]]; then
            # Shouldn't happen (wait -n returned but no tracked child died).
            # Avoid a busy spin if it does.
            sleep 1
            continue
        fi

        local name="${WAVE_PID2NAME[$finished]}"
        local elapsed=$(( $(date +%s) - WAVE_PID2START[$finished] ))
        unset 'WAVE_PID2NAME[$finished]'
        unset 'WAVE_PID2START[$finished]'

        if (( status != 0 )); then
            echo "ERROR: $name failed (exit $status, after ${elapsed}s)" >&2
            local victims=()
            for p in "${!WAVE_PID2NAME[@]}"; do
                victims+=("${WAVE_PID2NAME[$p]}")
            done
            if (( ${#victims[@]} > 0 )); then
                echo "  Killing ${#victims[@]} peer(s) in this wave: ${victims[*]}" >&2
            fi
            _kill_wave_peers
            _stop_heartbeat
            return 1
        fi

        echo "  $name OK (${elapsed}s)"

        if (( idx < n )); then
            _launch_one "${RUN_DESIGNS[$idx]}"
            idx=$(( idx + 1 ))
        fi
        _refresh_hb_state
    done

    _stop_heartbeat
    return 0
}

# ---------------------------------------------------------------------------
# Per-job wave runner: launch up to <par> backgrounded `make compile_essent_<d>`
# jobs at once, where every job carries its own ESSENT_JAR / ESSENT_RANK /
# ESSENT_EXTRA_ARGS (unlike run_make_wave, which shares one extra-args set
# across all jobs in the wave). Used only by ALL_RANKS_PARALLEL=1 mode.
#
# Inputs:
#   $1                concurrency cap (par)
#   JOB_DESIGN[@]     parallel arrays (read from caller scope) — one entry per
#   JOB_JAR[@]        scheduled (design, rank) pair, in dispatch order. The
#   JOB_RANK[@]       label is what shows up in stdout, heartbeat, error
#   JOB_EXTRAARGS[@]  messages, etc. ML jobs should be at the front so they
#   JOB_LABEL[@]      get the slots first when par < NJOBS.
# ---------------------------------------------------------------------------
run_make_wave_perjob() {
    local par="$1"
    local mk_prefix="compile_essent"
    local n=${#JOB_DESIGN[@]}
    local idx=0

    WAVE_PID2NAME=()
    WAVE_PID2START=()
    : > "$HB_STATE_FILE"
    _start_heartbeat

    _launch_one_perjob() {
        local i="$1"
        local d="${JOB_DESIGN[$i]}"
        local jar="${JOB_JAR[$i]}"
        local rank="${JOB_RANK[$i]}"
        local extra_args="${JOB_EXTRAARGS[$i]}"
        local label="${JOB_LABEL[$i]}"
        echo "  $label ..."
        local -a passthrough=("ESSENT_JAR=$jar" "ESSENT_RANK=$rank")
        [[ -n "$extra_args" ]] && passthrough+=("ESSENT_EXTRA_ARGS=$extra_args")
        [[ -n "$ESSENT_CXX" ]] && passthrough+=("CXX=$ESSENT_CXX" "LINK=$ESSENT_CXX")
        (
            cd "$ESSENT_MLDEDUP"
            exec make -j"$JOBS_PER_DESIGN" "${mk_prefix}_${d}" "${passthrough[@]}"
        ) &
        local pid=$!
        WAVE_PID2NAME[$pid]="$label"
        WAVE_PID2START[$pid]=$(date +%s)
    }

    while (( idx < n )) && (( ${#WAVE_PID2NAME[@]} < par )); do
        _launch_one_perjob "$idx"
        idx=$(( idx + 1 ))
    done
    _refresh_hb_state

    while (( ${#WAVE_PID2NAME[@]} > 0 )); do
        local status=0
        wait -n 2>/dev/null || status=$?
        local finished=""
        local p
        for p in "${!WAVE_PID2NAME[@]}"; do
            if ! kill -0 "$p" 2>/dev/null; then
                finished="$p"
                break
            fi
        done
        if [[ -z "$finished" ]]; then
            sleep 1
            continue
        fi

        local name="${WAVE_PID2NAME[$finished]}"
        local elapsed=$(( $(date +%s) - WAVE_PID2START[$finished] ))
        unset 'WAVE_PID2NAME[$finished]'
        unset 'WAVE_PID2START[$finished]'

        if (( status != 0 )); then
            echo "ERROR: $name failed (exit $status, after ${elapsed}s)" >&2
            local victims=()
            for p in "${!WAVE_PID2NAME[@]}"; do
                victims+=("${WAVE_PID2NAME[$p]}")
            done
            if (( ${#victims[@]} > 0 )); then
                echo "  Killing ${#victims[@]} peer(s) in this wave: ${victims[*]}" >&2
            fi
            _kill_wave_peers
            _stop_heartbeat
            return 1
        fi

        echo "  $name OK (${elapsed}s)"

        if (( idx < n )); then
            _launch_one_perjob "$idx"
            idx=$(( idx + 1 ))
        fi
        _refresh_hb_state
    done

    _stop_heartbeat
    return 0
}

# Compile a single jar's emulators across all DESIGNS in one wave. Same
# CXX, same opt flags for every design (see top-of-file docstring on why we
# no longer split into light/heavy tiers).
compile_essent_for_jar() {
    local label="$1" jar="$2" rank="$3"
    local todo=()
    local d
    for d in "${DESIGNS[@]}"; do
        if _is_compiled "$d" "$rank"; then
            echo "  compile_essent_${d} SKIP (emulator_essent_${d}_r${rank} already exists)"
            continue
        fi
        todo+=("$d")
    done

    if (( ${#todo[@]} == 0 )); then
        return 0
    fi

    # The ML jar needs `--ml-rank` on the essent.Driver command line to pick
    # the model's chosen dedup target. We detect by basename so any caller
    # (single-jar mode, ESSENT_JAR_STEPS, rank sweep, or the post-sweep ML
    # pass) gets the flag forwarded automatically.
    local extra_essent_args=""
    if [[ "$(basename "$jar")" == "essent-ml.jar" ]]; then
        extra_essent_args="--ml-rank"
    fi

    echo ""
    echo "=== Compile $label → _r${rank}  (${#todo[@]} design(s), par=$DESIGN_PARALLEL${ESSENT_CXX:+, CXX=$ESSENT_CXX}${extra_essent_args:+, ESSENT_EXTRA_ARGS=$extra_essent_args}) ==="
    RUN_DESIGNS=("${todo[@]}")
    local -a wave_extra=("ESSENT_JAR=$jar" "ESSENT_RANK=$rank")
    if [[ -n "$extra_essent_args" ]]; then
        wave_extra+=("ESSENT_EXTRA_ARGS=$extra_essent_args")
    fi
    if [[ -n "$ESSENT_CXX" ]]; then
        wave_extra+=("CXX=$ESSENT_CXX" "LINK=$ESSENT_CXX")
    fi
    run_make_wave "$DESIGN_PARALLEL" compile_essent "${wave_extra[@]}"
}

# ---------------------------------------------------------------------------
# Global cleanup: on any exit (normal or interrupted), make sure no stray
# wave / heartbeat children survive.
# ---------------------------------------------------------------------------
HB_STATE_FILE="$(mktemp)"

_global_cleanup() {
    local rc=$?
    _stop_heartbeat || true
    if (( ${#WAVE_PID2NAME[@]} > 0 )); then
        _kill_wave_peers
    fi
    rm -f "$HB_STATE_FILE" 2>/dev/null || true
    # Always write the pipelining sentinel — even on failure / SIGINT — so any
    # run_benchmarks.sh --pipeline consumer can stop waiting. `2>/dev/null` in
    # case the log dir was never created (e.g. early-exit before mkdir).
    if [[ -n "${COMPILE_COMPLETE_FLAG:-}" ]]; then
        printf 'rc=%d\nts=%s\n' "$rc" "$(date -Iseconds)" \
            > "$COMPILE_COMPLETE_FLAG" 2>/dev/null || true
    fi
    exit $rc
}
trap _global_cleanup EXIT INT TERM

echo "=== compile_emulators ==="
if [[ -n "$ESSENT_ONLY_JAR" ]]; then
    echo "    Mode:           single jar (ESSENT_ONLY_RANK=$ESSENT_ONLY_RANK)"
elif [[ "$ESSENT_RANK_SWEEP" == "1" ]]; then
    echo "    Mode:           rank sweep $MIN_RANK..$MAX_RANK  ($JAR_DIR/essent-${MIN_RANK}.jar … essent-${MAX_RANK}.jar)"
elif [[ "$ALL_RANKS_PARALLEL" == "1" ]]; then
    echo "    Mode:           ESSENT_JAR_STEPS, all-ranks-parallel ($ESSENT_JAR_STEPS)"
else
    echo "    Mode:           ESSENT_JAR_STEPS ($ESSENT_JAR_STEPS)"
fi
echo "    Designs:        ${DESIGNS[*]}"
if [[ "$ALL_RANKS_PARALLEL" == "1" && -z "$ESSENT_ONLY_JAR" && "$ESSENT_RANK_SWEEP" != "1" ]]; then
    # In all-ranks-parallel mode the real concurrency is set right before
    # dispatch (cap = NJOBS or ALL_RANKS_PARALLEL_CAP); the per-design wave
    # values used for prepare are not the right summary here.
    echo "    Concurrency:    all (design × jar) pairs concurrent (cap = ALL_RANKS_PARALLEL_CAP if set, else NJOBS)"
else
    echo "    Concurrency:    $DESIGN_PARALLEL design(s) at once → make -j$JOBS_PER_DESIGN per design"
fi
echo "    CXX:            ${ESSENT_CXX:-<system default g++>}"
echo "    Stack ulimit:   $(ulimit -s)"
echo "    Heartbeat:      every ${HEARTBEAT_INTERVAL}s (set HEARTBEAT_INTERVAL=0 to disable)"
echo "    Resume mode:    $([[ "$CLEAN" == "1" ]] && echo "disabled (CLEAN=1)" || echo "enabled (set CLEAN=1 to override)")"
echo ""

if [[ -n "$ESSENT_ONLY_JAR" ]]; then
    ONLY_JAR_PATH="$(_resolve_jar_path "$ESSENT_ONLY_JAR")"
    if [[ ! -f "$ONLY_JAR_PATH" ]]; then
        echo "ERROR: ESSENT_ONLY_JAR not found: $ONLY_JAR_PATH"
        exit 1
    fi
elif [[ "$ESSENT_RANK_SWEEP" == "1" ]]; then
    for k in $(seq "$MIN_RANK" "$MAX_RANK"); do
        JAR="$JAR_DIR/essent-${k}.jar"
        if [[ ! -f "$JAR" ]]; then
            echo "ERROR: jar not found: $JAR"
            echo "Build jars: cd $SYSML && ./build_essent_jars.sh"
            echo "Note: build_essent_jars.sh starts at essent-1.jar; for rank 0 copy a baseline jar to essent-0.jar."
            exit 1
        fi
    done
else
    for step in $ESSENT_JAR_STEPS; do
        [[ "$step" == *:* ]] || { echo "ERROR: bad ESSENT_JAR_STEPS entry (want jar:rank): $step"; exit 1; }
        jf="${step%%:*}"
        jp="$(_resolve_jar_path "$jf")"
        if [[ ! -f "$jp" ]]; then
            echo "ERROR: jar not found: $jp"
            exit 1
        fi
    done
fi

if [[ "$SKIP_SUBMOD" != "1" ]]; then
    if [[ ! -x "$SUBMOD_SH" ]]; then
        echo "ERROR: clone_spike.sh not found or not executable: $SUBMOD_SH"
        exit 1
    fi
    echo "=== Spike / riscv-isa-sim (clone_spike.sh mldedup) ==="
    bash "$SUBMOD_SH" mldedup
fi

mkdir -p "$ESSENT_MLDEDUP/emulator" "$ESSENT_MLDEDUP/log"

# Clear any stale pipelining sentinel from a previous (possibly crashed) run
# before we start producing fresh emulator binaries.
rm -f "$COMPILE_COMPLETE_FLAG" 2>/dev/null || true

echo "=== Prepare designs (once) ==="
_todo_prepare=()
for d in "${DESIGNS[@]}"; do
    if _is_prepared "$d"; then
        echo "  prepare_$d SKIP (already prepared)"
    else
        _todo_prepare+=("$d")
    fi
done
if (( ${#_todo_prepare[@]} > 0 )); then
    RUN_DESIGNS=("${_todo_prepare[@]}")
    run_make_wave "$DESIGN_PARALLEL" prepare
fi

for d in "${DESIGNS[@]}"; do
    if [[ ! -d "$ESSENT_MLDEDUP/build/$d" ]]; then
        echo "ERROR: prepare failed for design $d — missing $ESSENT_MLDEDUP/build/$d"
        exit 1
    fi
done

if [[ -n "$ESSENT_ONLY_JAR" ]]; then
    compile_essent_for_jar "$ESSENT_ONLY_JAR" "$ONLY_JAR_PATH" "$ESSENT_ONLY_RANK"
elif [[ "$ESSENT_RANK_SWEEP" == "1" ]]; then
    for k in $(seq "$MIN_RANK" "$MAX_RANK"); do
        JAR="$JAR_DIR/essent-${k}.jar"
        compile_essent_for_jar "essent-${k}.jar" "$JAR" "$k"
    done
    # ML jar pseudo-rank: append after the integer sweep so a single sweep
    # produces both the heuristic ranks (essent-<k>.jar -> _r<k>) and the
    # ML model's own pick (essent-ml.jar -> _rml). Skipped silently if the
    # ML jar is not present.
    ML_JAR="$JAR_DIR/essent-ml.jar"
    if [[ -f "$ML_JAR" ]]; then
        echo ""
        echo "=== Rank sweep complete; appending ML pseudo-rank (essent-ml.jar → _rml) ==="
        compile_essent_for_jar "essent-ml.jar" "$ML_JAR" "ml"
    else
        echo ""
        echo "Skipping ML pseudo-rank: $ML_JAR not found."
    fi
elif [[ "$ALL_RANKS_PARALLEL" == "1" ]]; then
    # Fan out (design × jar) into one wave. Job order = ESSENT_JAR_STEPS
    # outer loop × DESIGNS inner loop, so all ML jobs land at the head of
    # the queue (then rank 1, then rank 0). When the concurrency cap covers
    # the full job list, this is just "all 48 race"; when it doesn't, ML
    # finishes first because it grabs the slots first.
    JOB_DESIGN=()
    JOB_JAR=()
    JOB_RANK=()
    JOB_LABEL=()
    JOB_EXTRAARGS=()
    for step in $ESSENT_JAR_STEPS; do
        jf="${step%%:*}"
        rk="${step#*:}"
        JAR="$(_resolve_jar_path "$jf")"
        extra_args=""
        if [[ "$(basename "$JAR")" == "essent-ml.jar" ]]; then
            extra_args="--ml-rank"
        fi
        for d in "${DESIGNS[@]}"; do
            if _is_compiled "$d" "$rk"; then
                echo "  compile_essent_${d}_r${rk} SKIP (emulator_essent_${d}_r${rk} already exists)"
                continue
            fi
            JOB_DESIGN+=("$d")
            JOB_JAR+=("$JAR")
            JOB_RANK+=("$rk")
            JOB_EXTRAARGS+=("$extra_args")
            JOB_LABEL+=("compile_essent_${d}_r${rk}")
        done
    done

    NJOBS=${#JOB_DESIGN[@]}
    if (( NJOBS == 0 )); then
        echo ""
        echo "(all-ranks-parallel: nothing to do — all targets already compiled)"
    else
        # Concurrency cap defaults to all jobs; user can constrain via
        # ALL_RANKS_PARALLEL_CAP if RAM is tight (e.g. 24 to keep peak ≲ 700 GiB).
        WAVE_CAP="${ALL_RANKS_PARALLEL_CAP:-$NJOBS}"
        if ! [[ "$WAVE_CAP" =~ ^[0-9]+$ ]] || (( WAVE_CAP < 1 )); then
            echo "ERROR: ALL_RANKS_PARALLEL_CAP must be a positive integer (got: $WAVE_CAP)"
            exit 1
        fi
        (( WAVE_CAP > NJOBS )) && WAVE_CAP="$NJOBS"
        # Re-divide make -j across the wider concurrency. The original
        # JOBS_PER_DESIGN was sized for DESIGN_PARALLEL designs at once; with
        # 3× more concurrent jobs each gets 1/3 the threads.
        JOBS_PER_DESIGN=$(( PARALLEL / WAVE_CAP ))
        (( JOBS_PER_DESIGN < 1 )) && JOBS_PER_DESIGN=1
        echo ""
        echo "=== Compile (all-ranks parallel)  ($NJOBS job(s) across ranks, par=$WAVE_CAP, make -j$JOBS_PER_DESIGN per job${ESSENT_CXX:+, CXX=$ESSENT_CXX}) ==="
        run_make_wave_perjob "$WAVE_CAP"
    fi
else
    for step in $ESSENT_JAR_STEPS; do
        jf="${step%%:*}"
        rk="${step#*:}"
        JAR="$(_resolve_jar_path "$jf")"
        compile_essent_for_jar "$jf" "$JAR" "$rk"
    done
fi

echo ""
echo "=== Merging per-run dedup feature CSVs ==="
COMBINED="$ESSENT_MLDEDUP/log/dedup_features_all.csv"
INDIVIDUAL_CSVS=()
while IFS= read -r f; do
    [[ "$f" == "$COMBINED" ]] && continue
    INDIVIDUAL_CSVS+=("$f")
done < <(ls "$ESSENT_MLDEDUP/log"/dedup_features_*.csv 2>/dev/null)
if (( ${#INDIVIDUAL_CSVS[@]} > 0 )); then
    head -1 "${INDIVIDUAL_CSVS[0]}" > "$COMBINED"
    for f in "${INDIVIDUAL_CSVS[@]}"; do
        tail -n +2 "$f" >> "$COMBINED"
    done
    echo "Combined features CSV: $COMBINED ($(tail -n +2 "$COMBINED" | wc -l) data rows)"
    mkdir -p "$REPO_ROOT/data"
    cp "$COMBINED" "$REPO_ROOT/data/dedup_features.csv"
    echo "Copied to $REPO_ROOT/data/dedup_features.csv"
else
    echo "WARNING: no dedup_features_*.csv files found in $ESSENT_MLDEDUP/log/"
fi

echo ""
echo "=== compile_emulators complete ==="
echo "Binaries under $ESSENT_MLDEDUP/emulator/ matching emulator_essent_*_r<rank or suffix>"

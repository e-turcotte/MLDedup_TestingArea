# MLDedup Simulator Throughput Experiments

Measure and predict the throughput impact of module deduplication in
ESSENT-generated hardware simulators.

## Why this testing area exists

The ML model in `../MLDedup/model/` needs labelled training data — ground-truth
measurements of how fast each dedup choice actually runs. Those labels do not
exist in the compiler; they can only come from **building simulators, running
real benchmarks, and measuring throughput**. This directory automates that
entire data-collection loop.

The core question is: *for a given design, which module rank produces the
fastest simulator?* To answer it, we compile one emulator per rank (0 through
10), run every emulator against a matrix of benchmarks and host-parallelism
levels, measure throughput (simulated cycles per wall-clock second), and
assemble the results into the `regression_dataset.csv` that the training
pipeline consumes.

Without this infrastructure, there is no way to train or validate the ML model.
The testing area is the bridge between the compiler (which produces features
and emulators) and the model (which learns from measured speedups).

## How configuration works

Experiment scope is controlled by two layers:

**`execution/settings.py`** defines the default experiment matrix:
- `benchmarks_to_consider` — which RISC-V benchmarks to run (e.g. vvadd,
  qsort, mm). These are single-threaded binaries from `mt-benchmarks/`.
- `parallel_cpus` — host-side parallelism levels to test (e.g. 1, 4, 8, 12).
  Higher values mean more simulator threads.
- `tested_designs` — which chip designs to test (e.g. rocket21-1c, boom21-2large).
  Overridable via the `MLDEDUP_TEST_DESIGNS` environment variable.
- `max_concurrent_runs` — how many simulations to run in parallel on the host.

**`execution/run_benchmarks.sh`** CLI flags narrow the matrix for a specific
run: `--benchmarks`, `--parallel-cpus`, `--designs`, `--min-rank`/`--max-rank`.
These set environment variables (`MLDEDUP_SLIM_SWEEP`, `MLDEDUP_BENCHMARK_NAMES`,
etc.) that `settings.py` reads to filter the Cartesian product.

**`execution/configs.py`** maps abstract names to concrete paths: which
binary to run for a given benchmark, which emulator directory to look in for a
given simulator type, and how to resolve ranked emulator paths
(`emulator_essent_<design>_r<rank>`).

## Directory Layout

```
.
├── Makefile                            # Root build orchestration
│
├── compilation/                        # Emulator build scripts
│   ├── compile_emulators.sh            # Builds ranked MLDedup emulators
│   └── clone_spike.sh                  # Clones riscv-isa-sim (Spike) per design
│
├── execution/                          # Benchmark measurement
│   ├── run_benchmarks.sh              # Rank sweep entry point
│   ├── measure_throughput.py          # Runs throughput tests, writes to log/
│   ├── measure_cat.py                 # L3 CAT sweep measurement (for Figure 2)
│   ├── configs.py                     # Paths, benchmark map, simulator/design metadata
│   ├── settings.py                    # Experiment knobs (benchmarks, parallelism, designs)
│   └── task_runner.py                 # Thread-pool task runner for parallel simulation
│
├── analysis/                           # Dataset building and visualization
│   ├── build_dataset.py               # Throughput logs + features -> regression CSV
│   ├── plot_rank_throughput.py        # Rank vs throughput plots
│   ├── generate_paper_figures.py      # Entry point for paper Figures 2/8/9
│   ├── plot_figure2.py                # Figure 2 (L3 CAT allocation)
│   ├── plot_figure8.py                # Figure 8 (relative simulation speed)
│   ├── plot_figure9.py                # Figure 9 (throughput scalability)
│   ├── plot_styles.py                 # Matplotlib colors, markers, linestyles
│   └── log_parser.py                  # Log-parsing helpers (throughput, exec time)
│
├── data/                               # Generated datasets
│   ├── dedup_features.csv             # Dedup module features per (design, rank)
│   ├── throughput_data.csv            # Raw parsed throughput data
│   └── regression_dataset.csv         # Final LTR regression dataset
│
├── results/                            # Archived benchmark runs
│   └── <timestamp>/
│       └── rank*/                     # manifest.txt, throughput_logs/, essent_logs/
│
├── essent-mldedup/                     # MLDedup simulator build tree
├── mt-benchmarks/                      # RISC-V benchmark binaries (bin-1t/ .. bin-8t/)
│
├── log/                                # Runtime logs (gitignored)
└── temp/                               # Scratch space (gitignored)
```

## Workflow

All commands are run from the repo root.

### 1. Build emulators

Compile ranked emulators for each design (requires `../jars/essent-{0..10}.jar`):

```bash
./compilation/compile_emulators.sh
```

Produces `essent-mldedup/emulator/emulator_essent_<design>_r<rank>` binaries and copies dedup feature CSVs to `data/dedup_features.csv`.

### 2. Run benchmarks

```bash
./execution/run_benchmarks.sh --archive results --benchmarks vvadd,qsort --parallel-cpus 1,16
```

Results are archived under `results/<timestamp>/rank*/`.

### 3. Build regression dataset

```bash
python3 analysis/build_dataset.py results/<timestamp>/
```

Produces `data/regression_dataset.csv` — the file the ML training pipeline
(`../MLDedup/model/`) consumes. Understanding its structure is important:

**One row = one experiment point.** Each row represents a single
(design, rank, benchmark, parallel_cpus) combination. For example, running
6 designs x 10 ranks x 10 benchmarks x 4 parallelism levels produces
up to 2400 rows.

**How the columns are assembled.** `build_dataset.py` joins two data sources:

1. **Throughput logs** (from step 2) — parsed from the archived
   `rank*/throughput_logs/` directory. For each combination, the script extracts
   simulated cycle count and wall-clock time from log files, computes throughput
   as `cycles / elapsed_seconds`, and takes the median across repeated runs.

2. **Dedup features** (from step 1) — the structural features that the compiler
   wrote to `data/dedup_features.csv` during compilation. These are the same
   7 features the ML model uses: `instance_count`, `module_ir_size`,
   `boundary_signal_count`, `boundary_to_interior_ratio`, `edge_count_within`,
   `fraction_design_covered`, `original_ir_size`.

The two sources are joined on `(design, rank)`. The key derived column is:

- **`relative_speedup`** = `median_throughput_hz / baseline_throughput_hz`,
  where the baseline is the rank-0 (no dedup) emulator for the same
  (design, benchmark, parallel_cpus) group. A value of 1.05 means the
  ranked emulator is 5% faster than no dedup; 0.95 means 5% slower.

This is the target variable that the ML model learns to predict. The model
does not need to predict absolute throughput — only *relative* improvement
over the no-dedup baseline, which controls for benchmark difficulty and
host-machine speed.

### 4. Plot rank vs throughput

```bash
python3 analysis/plot_rank_throughput.py --csv data/throughput_data.csv --min-rank 0 --max-rank 10 -o sweep.pdf
```

### 5. Generate paper figures (optional)

Requires matplotlib. Run from the repo root:

```bash
python3 -m analysis.generate_paper_figures
```

Produces `Figure2.pdf`, `Figure8.pdf`, and `Figure9.pdf`. Figure 2 requires `execution/measure_cat.py` to have been run first.

## Dependencies

- Python 3.8+
- matplotlib (plotting only, not needed on the benchmark server)
- RISC-V GCC toolchain + picolibc (for building benchmarks in `mt-benchmarks/`)
- ESSENT jars at `../jars/essent-{0..10}.jar`

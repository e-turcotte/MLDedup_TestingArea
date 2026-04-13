# MLDedup Simulator Throughput Experiments

Measure and predict the throughput impact of module deduplication in ESSENT-generated hardware simulators.

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

Produces `data/regression_dataset.csv` with one row per (design, rank, benchmark, parallel_cpus) combination, where the target variable is relative speedup vs rank 0.

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

#!/bin/env python3

import os
import sys
import configs


#####################
# Configuration start
#####################

# throughput: 8 benchmarks; each design runs Nt-{bench} where N = design cores (1c→1t, 2c→2t, ...)
benchmarks_to_consider = ["vvadd", "multiply", "matmul", "memcpy", "mm", "qsort", "spmv", "rsort"]
# Note: Affects simulation parallelism.
parallel_cpus = [1, 4, 8, 12]
# Number of run configs to execute in parallel (override with MEASURE_MAX_CONCURRENT_RUNS).
max_concurrent_runs = int(os.environ.get("MEASURE_MAX_CONCURRENT_RUNS", "2"))


assert(1 in parallel_cpus)

# CAT
monitor_benchmarks = ["vvadd"]
# Note: monitor_designs will be traversed by measure_cat.py
monitor_designs = ["boom21-6large"]
monitor_simulators = ["verilator", "essent", "dedup"]
monitor_iterations = 1


#####################
# Configuration end
#####################

# Mem BW
# membw_bench = ['vvadd']
# membw_designs = ["rocket21-1c", "boom21-6large"]
# membw_simulators = ['verilator', 'essent', 'dedup']
# membw_parallel_cpus = [1, 4, 8, 12]


# All rocket21 CPU types; benchmark thread version matches design (1c→1t, 2c→2t, ...)
# Overridden when BOOM_THROUGHPUT_ONLY=1 (prepare_and_compile.sh boom flow)
# or MLDEDUP_TEST_DESIGNS=comma,separated,list (rank sweep flow)
tested_designs = [
    'rocket21-1c', 'rocket21-2c', 'rocket21-4c', 'rocket21-6c', 'rocket21-8c',
]
if os.environ.get("MLDEDUP_TEST_DESIGNS"):
    tested_designs = [d.strip() for d in os.environ["MLDEDUP_TEST_DESIGNS"].split(",") if d.strip()]
elif os.environ.get("BOOM_THROUGHPUT_ONLY"):
    tested_designs = [
        'boom21-small', 'boom21-2small', 'boom21-4small',
        'boom21-large', 'boom21-2large', 'boom21-4large',
    ]

# Must match tested_designs (used by plot.py assertion)
tested_design_groups = [
    ['rocket21-1c', 'rocket21-2c', 'rocket21-4c', 'rocket21-6c', 'rocket21-8c'],
    # ['boom21-small', 'boom21-2small', 'boom21-4small', 'boom21-6small', 'boom21-8small'],
    # ['boom21-large', 'boom21-2large', 'boom21-4large', 'boom21-6large', 'boom21-8large'],
    # ['boom21-mega', 'boom21-2mega', "boom21-4mega", "boom21-6mega", "boom21-8mega"]
]

iterations = 1










perf_benchmarks = ["vvadd"]
perf_designs = ["rocket21-6c", "boom21-6small", "boom21-6large", "boom21-4mega"]
perf_simulators = configs.simulators
perf_iterations = 1

# perf_events_membw_intel = [
#     "llc_misses.mem_read",
#     "llc_misses.mem_write"
# ]

perf_events_intel = [
    "cycles",

    "L1-icache-load-misses",
    "l2_rqsts.code_rd_hit",
    "l2_rqsts.code_rd_miss",
    "l2_rqsts.miss",
    "l2_rqsts.pf_hit",
    "l2_rqsts.pf_miss",
    "LLC-load-misses",
    "LLC-loads",
    "LLC-store-misses",
    "LLC-stores",

    # [read requests to memory controller. Derived from unc_m_cas_count.rd. Unit: uncore_imc]
    "llc_misses.mem_read",
    # [write requests to memory controller. Derived from unc_m_cas_count.wr. Unit: uncore_imc]
    "llc_misses.mem_write",

    # # [Read Pending Queue Allocations. Unit: uncore_imc]
    # "unc_m_rpq_inserts",
    # # [Read Pending Queue Occupancy. Unit: uncore_imc]
    # "unc_m_rpq_occupancy",
    # # [All hits to Near Memory(DRAM cache) in Memory Mode. Unit: uncore_imc]
    # "unc_m_tagchk.hit",
    # # [All Clean line misses to Near Memory(DRAM cache) in Memory Mode. Unit: uncore_imc]
    # "unc_m_tagchk.miss_clean",
    # # [All dirty line misses to Near Memory(DRAM cache) in Memory Mode. Unit: uncore_imc]
    # "unc_m_tagchk.miss_dirty",
    # # [Write Pending Queue Allocations. Unit: uncore_imc]
    # "unc_m_wpq_inserts", 
    # # [Write Pending Queue Occupancy. Unit: uncore_imc]
    # "unc_m_wpq_occupancy",
    

    "instructions",
    "branches",
    "branch-misses", 
    # Counts the total number when the front end is resteered, mainly when the BPU cannot provide a correct prediction and this is corrected by other branch handling mechanisms at the front end
    "baclears.any", 
    # All (macro) branch instructions retired Spec update: SKL091
    "br_inst_retired.all_branches", 
    # All mispredicted macro branch instructions retired
    "br_misp_retired.all_branches", 
    # Conditional branch instructions retired Spec update: SKL091 (Precise event)
    "br_inst_retired.conditional", 
    # Mispredicted conditional branch instructions retired (Precise event)
    "br_misp_retired.conditional", 
    # Direct and indirect near call instructions retired Spec update: SKL091 (Precise event)
    "br_inst_retired.near_call", 
    # Mispredicted direct and indirect near call instructions retired (Precise event)
    "br_misp_retired.near_call", 

    "cycle_activity.stalls_total",
    "cycle_activity.stalls_mem_any",
    "resource_stalls.any",

       

    # Pipeline gaps in the frontend
    "topdown-fetch-bubbles", 
    # Pipeline gaps during recovery from misspeculation
    "topdown-recovery-bubbles", 
    # Cycles where a code fetch is stalled due to L1 instruction cache miss
    "icache_16b.ifdata_stall", 
    # Instruction fetch tag lookups that hit in the instruction cache (L1I). Counts at 64-byte cache-line granularity
    "icache_64b.iftag_stall", 

    # # Cycles when uops are being delivered to Instruction Decode Queue (IDQ) from Decode Stream Buffer (DSB) path
    # "idq.dsb_cycles", 
    # # Cycles when uops are being delivered to Instruction Decode Queue (IDQ) from MITE path
    # "idq.mite_cycles", 
    # # Cycles Decode Stream Buffer (DSB) is delivering any Uop
    # "idq.all_dsb_cycles_any_uops", 
    # # Cycles MITE is delivering any Uop
    # "idq.all_mite_cycles_any_uops", 
    # # Cycles the issue-stage is waiting for front-end to fetch from resteered path following branch misprediction or machine clear events
    # "int_misc.clear_resteer_cycles",

    "L1-dcache-load-misses", 
    "L1-dcache-loads", 
    "L1-dcache-stores", 
    "l2_rqsts.all_demand_data_rd", 
    "l2_rqsts.all_demand_miss", 
    "mem_load_retired.l1_hit", 
    "mem_load_retired.l1_miss", 
    "mem_load_retired.l2_hit", 
    "mem_load_retired.l2_miss"
]




def get_monitor_settings():
    ret = []
    for sim in monitor_simulators:
        for design in monitor_designs:
            design_cores = configs.design_cores[design]
            for bench in benchmarks_to_consider:
                benchmark = f"{design_cores}t-{bench}"
                ret.append((sim, design, benchmark, monitor_iterations))
    return ret





def get_perf_settings():
    ret = []
    for sim in perf_simulators:
        for design in perf_designs:
            design_cores = configs.design_cores[design]
            for bench in benchmarks_to_consider:
                benchmark = f"{design_cores}t-{bench}"
                ret.append((sim, design, benchmark, perf_iterations))
    return ret


def get_throughput_settings():
    ret = []
    sims = configs.simulators
    if os.environ.get("MLDEDUP_ONLY_THROUGHPUT") or os.environ.get("BOOM_THROUGHPUT_ONLY"):
        sims = ["mldedup"]

    effective_benchmarks = benchmarks_to_consider
    effective_parallel_cpus = parallel_cpus
    if os.environ.get("MLDEDUP_SMOKE"):
        effective_benchmarks = ["vvadd"]
        effective_parallel_cpus = [1]
    elif os.environ.get("MLDEDUP_SLIM_SWEEP"):
        # Narrow benchmark / host-parallelism lists; defaults match minimal slim experiment.
        # Cartesian product: designs × effective_benchmarks × effective_parallel_cpus
        valid_bench = set(benchmarks_to_consider)
        raw_b = os.environ.get("MLDEDUP_BENCHMARK_NAMES", "vvadd").strip()
        if not raw_b:
            name_tokens = ["vvadd"]
        else:
            name_tokens = [x.strip() for x in raw_b.split(",") if x.strip()]
        effective_benchmarks = []
        for n in name_tokens:
            if n in valid_bench:
                effective_benchmarks.append(n)
            else:
                print(
                    f"Warning: MLDEDUP_BENCHMARK_NAMES ignores unknown benchmark {n!r} "
                    f"(not in benchmarks_to_consider)",
                    file=sys.stderr,
                )
        if not effective_benchmarks:
            raise ValueError(
                "MLDEDUP_SLIM_SWEEP: no valid benchmark names in MLDEDUP_BENCHMARK_NAMES "
                f"(allowed: {benchmarks_to_consider})"
            )

        raw_p = os.environ.get("MLDEDUP_PARALLEL_CPUS", "12").strip()
        if not raw_p:
            effective_parallel_cpus = [12]
        else:
            effective_parallel_cpus = []
            for x in raw_p.split(","):
                x = x.strip()
                if not x:
                    continue
                effective_parallel_cpus.append(int(x))
        if not effective_parallel_cpus:
            raise ValueError(
                "MLDEDUP_SLIM_SWEEP: MLDEDUP_PARALLEL_CPUS parsed to an empty list"
            )

    for sim in sims:
        for design in tested_designs:
            design_cores = configs.design_cores[design]
            for bench in effective_benchmarks:
                benchmark = f"{design_cores}t-{bench}"
                for ncpus in effective_parallel_cpus:
                    ret.append((sim, design, benchmark, ncpus, iterations))

    return ret



# def get_throughput_membw_settings():
#     iterations = 1
#     ret = []

#     for sim in membw_simulators:
#         for design in membw_designs:
#             design_cores = configs.design_cores[design]
#             for bench in membw_bench:
#                 benchmark = f"{design_cores}t-{bench}"
#                 for ncpus in membw_parallel_cpus:
#                     ret.append((sim, design, benchmark, ncpus, iterations))

#     return ret
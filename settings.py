#!/bin/env python3

import configs


#####################
# Configuration start
#####################

# throughput
benchmarks_to_consider = ["vvadd"]
# Note: Affects simulation parallelism. 
parallel_cpus = [1, 4, 8, 12]


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


# Note: for now boom21-mega and boom21-2mega has only 1t performance. Should be enough for this paper
tested_designs = [
    'rocket21-1c', 'rocket21-2c', 'rocket21-4c', "rocket21-6c", 'rocket21-8c', 
    'boom21-small', 'boom21-2small', 'boom21-4small', 'boom21-6small', 'boom21-8small',
    'boom21-large', 'boom21-2large', 'boom21-4large', 'boom21-6large', "boom21-8large",
    'boom21-mega', 'boom21-2mega', "boom21-4mega", "boom21-6mega", "boom21-8mega"]

tested_design_groups = [
    ['rocket21-1c', 'rocket21-2c', 'rocket21-4c', "rocket21-6c", 'rocket21-8c'], 
    ['boom21-small', 'boom21-2small', 'boom21-4small', 'boom21-6small', 'boom21-8small'],
    ['boom21-large', 'boom21-2large', 'boom21-4large', 'boom21-6large', 'boom21-8large'],
    ['boom21-mega', 'boom21-2mega', "boom21-4mega", "boom21-6mega", "boom21-8mega"]]

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

    for sim in configs.simulators:
        for design in tested_designs:
            # if configs.get_simulator_path(sim, design, False) is None:
            #     continue
            design_cores = configs.design_cores[design]
            for bench in benchmarks_to_consider:
                benchmark = f"{design_cores}t-{bench}"
                for ncpus in parallel_cpus:
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
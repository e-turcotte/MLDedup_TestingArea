#!/bin/env python3

import os
import re

base_dir = os.getcwd()
temp_dir = os.path.join(base_dir, "temp/")
log_dir = os.path.join(base_dir, "log/")
benchmark_dir = os.path.join(base_dir, "mt-benchmarks/")

benchmarks = {
    "st-dhrystone": f"{benchmark_dir}bin-1t/dhrystone.riscv",
    "st-qsort": f"{benchmark_dir}bin-1t/qsort.riscv",
    "1t-memcpy": f"{benchmark_dir}bin-1t/mt-memcpy.riscv",
    "2t-memcpy": f"{benchmark_dir}bin-2t/mt-memcpy.riscv",
    "4t-memcpy": f"{benchmark_dir}bin-4t/mt-memcpy.riscv",
    "6t-memcpy": f"{benchmark_dir}bin-6t/mt-memcpy.riscv",
    "8t-memcpy": f"{benchmark_dir}bin-8t/mt-memcpy.riscv",
    "1t-matmul": f"{benchmark_dir}bin-1t/mt-matmul.riscv",
    "2t-matmul": f"{benchmark_dir}bin-2t/mt-matmul.riscv",
    "4t-matmul": f"{benchmark_dir}bin-4t/mt-matmul.riscv",
    "6t-matmul": f"{benchmark_dir}bin-6t/mt-matmul.riscv",
    "8t-matmul": f"{benchmark_dir}bin-8t/mt-matmul.riscv",
    "1t-vvadd": f"{benchmark_dir}bin-1t/mt-vvadd.riscv",
    "2t-vvadd": f"{benchmark_dir}bin-2t/mt-vvadd.riscv",
    "4t-vvadd": f"{benchmark_dir}bin-4t/mt-vvadd.riscv",
    "6t-vvadd": f"{benchmark_dir}bin-6t/mt-vvadd.riscv",
    "8t-vvadd": f"{benchmark_dir}bin-8t/mt-vvadd.riscv",
}



simulators = [
    "comm",
    "verilator",
    "verilator-nodedup",
    "essent",
    "dedup",
    "po",
    "dedup-nolocality"
]

# simulators_predict = [
#     "comm",
#     "verilator",
#     "essent"
# ]

simulator_prettyname = {
    "comm": "Commercial",
    "verilator": "Verilator",
    "verilator-nodedup": "Verilator - NoDedup",
    "essent": "ESSENT",
    "dedup": "Dedup",
    "po": "PO",
    "dedup-nolocality": "NL"
}


simulatorToInternalNames = {
    "comm": "comm",
    "verilator": "verilator",
    "verilator-nodedup": "verilator",
    "essent": "essent",
    "dedup": "essent",
    "po": "essent",
    "dedup-nolocality": "essent"
}
simulatorToDirectory = {
    "comm": "comm",
    "verilator": "verilator",
    "verilator-nodedup": "verilator-nodedup",
    "essent": "essent-master",
    "dedup": "essent-dedup",
    "po": "essent-po",
    "dedup-nolocality": "essent-dedup-no-locality"
}


designs = [
    'rocket21-1c',
    'rocket21-2c',
    'rocket21-4c',
    'rocket21-6c',
    'rocket21-8c',
    'boom21-small',
    'boom21-large',
    'boom21-mega',
    'boom21-2small',
    'boom21-2large',
    'boom21-2mega',
    'boom21-4small',
    'boom21-4large',
    'boom21-4mega',
    'boom21-6small',
    'boom21-6large',
    'boom21-6mega',
    'boom21-8small',
    'boom21-8large',
    'boom21-8mega',
]


design_cores = {
    'rocket21-1c': 1,
    'rocket21-2c':2,
    'rocket21-4c':4,
    'rocket21-6c':6,
    'rocket21-8c':8,
    'boom21-small':1,
    'boom21-large':1,
    'boom21-mega':1,
    'boom21-2small':2,
    'boom21-2large':2,
    'boom21-2mega':2,
    'boom21-4small':4,
    'boom21-4large':4,
    'boom21-4mega':4,
    'boom21-6small':6,
    'boom21-6large':6,
    'boom21-6mega':6,
    'boom21-8small':8,
    'boom21-8large':8,
    'boom21-8mega':8,
}

design_prettyName = {
    'rocket21-1c': 'Rocket-1C',
    'rocket21-2c': 'Rocket-2C',
    'rocket21-4c': 'Rocket-4C',
    'rocket21-6c': 'Rocket-6C',
    'rocket21-8c': 'Rocket-8C',

    'boom21-small': 'SmallBoom-1C',
    'boom21-large': 'LargeBoom-1C',
    'boom21-mega':  'MegaBoom-1C',

    'boom21-2small': 'SmallBoom-2C',
    'boom21-2large': 'LargeBoom-2C',
    'boom21-2mega':  'MegaBoom-2C',

    'boom21-4small': 'SmallBoom-4C',
    'boom21-4large': 'LargeBoom-4C',
    'boom21-4mega':  'MegaBoom-4C',

    'boom21-6small': 'SmallBoom-6C',
    'boom21-6large': 'LargeBoom-6C',
    'boom21-6mega':  'MegaBoom-6C',

    'boom21-8small': 'SmallBoom-8C',
    'boom21-8large': 'LargeBoom-8C',
    'boom21-8mega':  'MegaBoom-8C',

}


def get_design_pretty_name(design):
    return design_prettyName[design]


benchmark_cores = {
    "st-dhrystone": 1,
    "st-qsort": 1,
    "1t-memcpy": 1,
    "2t-memcpy": 2,
    "4t-memcpy": 4,
    "6t-memcpy": 6,
    "8t-memcpy": 8,
    "1t-matmul": 1,
    "2t-matmul": 2,
    "4t-matmul": 4,
    "6t-matmul": 6,
    "8t-matmul": 8,
    "1t-vvadd": 1,
    "2t-vvadd": 2,
    "4t-vvadd": 4,
    "6t-vvadd": 6,
    "8t-vvadd": 8,
}


def get_simulator_path(simulator, design, hasActivityDump = False):

    simName = simulatorToInternalNames[simulator]
    simulator_name = f"emulator_{simName}_activity_dump_{design}" if hasActivityDump else f"emulator_{simName}_{design}"
    simulator_path = f"./{simulatorToDirectory[simulator]}/emulator/{simulator_name}"

    if os.path.exists(simulator_path):
        return simulator_path
    return None


#!/bin/env python3

import os
import re
import sys
import time
import json
import subprocess
import signal
import logging
import shutil

import settings
import configs



def parse_platform_capability():
    # Use msr interface as sysfs interface may miss some capabitlity on certain kernel version
    pqos_cmd = ['pqos', '--iface=msr', '-d']

    proc = subprocess.run(pqos_cmd, capture_output=True, text=True)
    # raise error if non-zero
    proc.check_returncode()

    pqos_out = proc.stdout


    has_L3_CAT = False
    has_MBM = False

    for line in pqos_out.splitlines():
        if line.find("L3 CAT") >= 0:
            has_L3_CAT = True
        if line.find("Memory Bandwidth Monitoring") >= 0:
            has_MBM = True

    if has_L3_CAT and has_MBM:
        return True
    
    print(pqos_out)
    print("Error: Missing capability (L3 CAT or MBM)")



def get_platform_cache_info(cpu_id):
    l3_size = open(f'/sys/devices/system/cpu/cpu{cpu_id}/cache/index3/size').read().strip()
    l3_assoc = int(open(f'/sys/devices/system/cpu/cpu{cpu_id}/cache/index3/ways_of_associativity').read().strip())

    return (l3_size, l3_assoc)



def get_cpu_socket_id(cpu_id):
    info = os.listdir(f"/sys/devices/system/cpu/cpu{cpu_id}")
    for each in info:
        if re.match(r'node\d+', each):
            node_id = int(re.findall(r'\d+', each)[0])
            return node_id
    print("Cannot find node id. Assume 0")
    return 0

def reset():
    proc = subprocess.run(['pqos', '--iface=msr', '-R'])
    proc.check_returncode()

def set_L3_CAT(cpu_id, required_sets, total_sets):
    # Reset
    reset()

    if required_sets == total_sets:
        # Only reset if allocate all caches
        return
    if required_sets == 0:
        print("Illegal argument. Cannot allocate 0 ways to a core")
        exit(-1)

    node_id = get_cpu_socket_id(cpu_id)
    target_mask = (1 << required_sets) - 1
    # other_mask = ((1 << total_sets) - 1) ^ target_mask

    # Set COS 1
    cmd = ['pqos', '--iface=msr', '-e', f'llc@{node_id}:1={hex(target_mask)}']
    proc = subprocess.run(cmd)
    proc.check_returncode()

    # Associate COS1
    cmd = ['pqos', '--iface=msr', '-a', f'llc:1={cpu_id}']
    proc = subprocess.run(cmd)
    proc.check_returncode()


# class MBMMonitor():
#     def __init__(self) -> None:
#         self.mbm_proc = None

#     def start_MBM(self, core_id, log_file):
#         cmd = ['pqos', '--iface=msr', '-m', 'all:1', '-o', log_file, '-u', 'csv', '-i', '10']
#         self.mbm_proc = subprocess.Popen(cmd)

#     def stop_MBM(self):
#         assert(self.mbm_proc is not None)
#         self.mbm_proc.send_signal(signal.SIGINT)
#         self.mbm_proc.communicate()






loggerList = [
    "Runner",
    "Tasks"
]
fmtStr = "\u001b[31m[%(asctime)s]\u001b[33m[%(name)s]\u001b[35m[%(levelname)s]\u001b[34m: \u001b[0m%(message)s"


def logSetup():
    for eachLoggerName in loggerList:
        formatter = logging.Formatter(fmtStr)
        handler = logging.StreamHandler()
        handler.setFormatter(formatter)

        fHandler = logging.FileHandler(f"{configs.log_dir}run-cat.log")
        fHandler.setFormatter(formatter)

        logger = logging.getLogger(eachLoggerName)
        logger.addHandler(handler)
        logger.addHandler(fHandler)

        logger.setLevel(logging.INFO)



l3_size, l3_assoc = 0, 0


def save_platform_info(filename):
    dat = {
        "L3 Size": l3_size,
        "L3 Ways": l3_assoc
    }
    with open(filename, 'w') as f:
        f.write(json.dumps(dat))



def run_monitor_test(simulator, design, benchmark, monitor_iterations, core_id):
    log = logging.getLogger("Runner")

    simulator_bin = configs.get_simulator_path(simulator, design, False)
    benchmark_path = configs.benchmarks[benchmark]

    if simulator_bin is None:
        print(f"Ignore {simulator} {design} as cannot find simulator binary")
        return False

    for enabled_ways in range(1, l3_assoc + 1):
        log.info(f"Allocate {enabled_ways} ways cache to core {core_id}")
        set_L3_CAT(core_id, enabled_ways, l3_assoc)

        for iter in range(0, monitor_iterations):
            log_stdout_filename = f"run-cat_stdout_{simulator}_{design}_{benchmark}_l3set-{enabled_ways}_{iter}.log"
            log_time_filename = f"run-cat_time_{simulator}_{design}_{benchmark}_l3set-{enabled_ways}_{iter}.log"
            # log_pqos_filename = f"monitor_pqos_{simulator}_{design}_{benchmark}_l3set-{enabled_ways}_{iter}.log"

            log_stdout_temppath = os.path.join(configs.temp_dir, log_stdout_filename)
            log_time_temppath = os.path.join(configs.temp_dir, log_time_filename)
            # log_pqos_temppath = os.path.join(configs.temp_dir, log_pqos_filename)

            log_stdout_logpath = os.path.join(configs.log_dir, log_stdout_filename)
            log_time_logpath = os.path.join(configs.log_dir, log_time_filename)
            # log_pqos_logpath = os.path.join(configs.log_dir, log_pqos_filename)

            cmd_prefix = f"/usr/bin/time -o {log_time_temppath} numactl -C {core_id}"

            simulator_cmd = f"{simulator_bin} -c {benchmark_path}"

            cmd = f"{cmd_prefix} {simulator_cmd} > {log_stdout_temppath} 2>&1"

            # monitor = MBMMonitor()
            # monitor.start_MBM(core_id, log_pqos_temppath)
            time.sleep(1)

            # run simulator
            log.info(f"Start simulator with {cmd}")
            proc = subprocess.run(cmd, shell=True)
            proc.check_returncode()

            # Done
            log.info("Done")
            # monitor.stop_MBM()

            log.info("Moving log files")
            shutil.move(log_stdout_temppath, log_stdout_logpath)
            shutil.move(log_time_temppath, log_time_logpath)
            # shutil.move(log_pqos_temppath, log_pqos_logpath)
    return True

        



def signal_handler(sig, frame):
    # reset CAT
    reset()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)



def help():
    print("Usage: sudo python3 measure_cat.py <core_id>")
    print("            <core_id>: specify on which core to run the test")


if __name__ == '__main__':

    if len(sys.argv) != 2:
        help()
        exit(-1)


    core_id = int(sys.argv[1])
    print(f"Run experiments on core {core_id}")

    l3_size, l3_assoc = get_platform_cache_info(core_id)

    logSetup()

    log = logging.getLogger("Tasks")


    
    log.warning("This script assumes processor has at least 1 L3 cache")

    euid = os.geteuid()
    if euid != 0:
        log.info("Promote to root")
        print("Script require root access. Restart using sudo..")
        args = ['sudo', sys.executable] + sys.argv + [os.environ]
        os.execlpe('sudo', *args)

    platform_info_filepath = os.path.join(configs.log_dir, "platform_info.json")
    log.info(f"Save platform info to {platform_info_filepath}")
    save_platform_info(platform_info_filepath)


    runs = settings.get_monitor_settings()

    for r in runs:
        log.info(str(r))

    for r in runs:
        run_monitor_test(*r, core_id)
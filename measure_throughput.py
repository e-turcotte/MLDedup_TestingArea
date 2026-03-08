#!/bin/env python3

import os 
import re
import sys
import time
import signal
import psutil
import shutil
import logging

import configs
import execloop


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

        fHandler = logging.FileHandler(f"{configs.log_dir}throughput.log")
        fHandler.setFormatter(formatter)

        logger = logging.getLogger(eachLoggerName)
        logger.addHandler(handler)
        logger.addHandler(fHandler)

        logger.setLevel(logging.INFO)



def run_throughput_test(simulator, design, benchmark_name, parallel_cpus, iterations = 2, kill_after = 3600):
    simulator_bin_path = configs.get_simulator_path(simulator, design, False)
    if simulator_bin_path is None:
        # simulator does not exist
        print(f"Test case skipped due to binary not available ({simulator}, {design}, {benchmark_name}, {parallel_cpus})")
        return False


    log = logging.getLogger("Runner")
    benchmark_path = configs.benchmarks[benchmark_name]
    log_files = []
    startTime = time.time()

    # # clear temp dir
    # cmd = f"rm -rf {configs.temp_dir}*"
    # print(cmd)
    # os.system(cmd)

    # Copy simulators so they have different inode, avoid linux kernel shares their code pages
    temp_sims = []
    for i in range(0, parallel_cpus):
        src_path = configs.get_simulator_path(simulator, design, False)
        dst_path = os.path.join(configs.temp_dir, f"emulator_{simulator}_{design}_{i}")
        temp_sims.append(dst_path)
        shutil.copy(src_path, dst_path)

    os.system("sync")
    log.debug("Simulator binary copied")

    # generate task list
    task_lists = []
    for iter in range(0, iterations):
        for emu_id, emu in enumerate(temp_sims):
            run_id = iter * parallel_cpus + emu_id
            log_stdout_filename = f"throughput_stdout_{simulator}_{design}_{benchmark_name}_{parallel_cpus}_{run_id}.log"
            log_time_filename = f"throughput_time_{simulator}_{design}_{benchmark_name}_{parallel_cpus}_{run_id}.log"
            cmd = f"/usr/bin/time -o {configs.temp_dir}{log_time_filename} {emu} -c {benchmark_path} > {configs.temp_dir}{log_stdout_filename} 2>&1"
            task_lists.append(cmd)
            log_files.append(log_stdout_filename)
            log_files.append(log_time_filename)

    # Fill with placeholder processes. Those processes are only used to put pressure
    placeholder_tasks = []
    for iter in range(0, iterations * 4):
        for emu in temp_sims:
            cmd = f"{emu} {benchmark_path} > /dev/null 2>&1"
            placeholder_tasks.append(cmd)


    essential_task_ids = list(range(0, len(task_lists)))

    global task_executor
    task_executor = execloop.ExpRunner(task_lists + placeholder_tasks, essential_task_ids, parallel_cpus)
    task_executor.run()


    # finished
    task_executor = None


    # Move all logs to log dir
    for ef in log_files:
        dst_filename = os.path.join(configs.log_dir, ef)
        if os.path.exists(dst_filename):
            log.warning(f"Warning: Log file [{dst_filename}] already exists. Will overwrite!")
            os.unlink(dst_filename)
        shutil.move(os.path.join(configs.temp_dir, ef), configs.log_dir)
    # clean up
    for ef in temp_sims:
        os.unlink(ef)

    endTime = time.time()
    log.info(f"Took {int(endTime - startTime)}s for this test")

    return True




def signal_handler(sig, frame):
    if task_executor is not None:
        print("Killing all simulators")
        task_executor.kill_all()
    else:
        print("No simulator running")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)







if __name__ == "__main__":

    import settings
    logSetup()

    log = logging.getLogger("Tasks")

    runs = settings.get_throughput_settings()

    for r in runs:
        log.info(f"{str(r)}")
    log.info(f"Total {len(runs)} tasks.")

    log.info("Go!")

    for r in runs:
        sim, design, benchmark, ncpus, iterations = r

        log.info(f"Start task: {str(r)}")
        succesful = run_throughput_test(*r)
        if succesful:
            time.sleep(5)




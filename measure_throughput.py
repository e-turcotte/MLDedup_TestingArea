#!/bin/env python3

import os
import re
import sys
import time
import signal
import threading
import shutil
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed

import configs
import execloop

# For parallel runs: track active ExpRunners so signal handler can kill all.
_active_executors_lock = threading.Lock()
_active_executors = set()
_shutdown_requested = False


loggerList = [
    "Runner",
    "Tasks"
]
fmtStr = "\u001b[31m[%(asctime)s]\u001b[33m[%(name)s]\u001b[35m[%(levelname)s]\u001b[34m: \u001b[0m%(message)s"


def logSetup():
    os.makedirs(configs.log_dir, exist_ok=True)
    os.makedirs(configs.temp_dir, exist_ok=True)
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



def run_throughput_test(simulator, design, benchmark_name, parallel_cpus, iterations=2, kill_after=3600, run_temp_dir=None, run_index=None):
    simulator_bin_path = configs.get_simulator_path(simulator, design, False)
    if simulator_bin_path is None:
        print(f"Test case skipped due to binary not available ({simulator}, {design}, {benchmark_name}, {parallel_cpus})")
        return False

    log = logging.getLogger("Runner")
    benchmark_path = configs.benchmarks[benchmark_name]
    log_files = []
    startTime = time.time()

    base_temp_dir = (run_temp_dir if run_temp_dir is not None else configs.temp_dir).rstrip(os.sep)
    if run_temp_dir is not None:
        os.makedirs(run_temp_dir, exist_ok=True)

    # Copy simulators so they have different inode, avoid linux kernel shares their code pages
    temp_sims = []
    for i in range(0, parallel_cpus):
        src_path = configs.get_simulator_path(simulator, design, False)
        dst_path = os.path.join(base_temp_dir, f"emulator_{simulator}_{design}_{i}")
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
            time_path = os.path.join(base_temp_dir, log_time_filename)
            stdout_path = os.path.join(base_temp_dir, log_stdout_filename)
            cmd = f"/usr/bin/time -o {time_path} {emu} -c {benchmark_path} > {stdout_path} 2>&1"
            task_lists.append(cmd)
            log_files.append(log_stdout_filename)
            log_files.append(log_time_filename)

    placeholder_tasks = []
    for iter in range(0, iterations * 4):
        for emu in temp_sims:
            cmd = f"{emu} {benchmark_path} > /dev/null 2>&1"
            placeholder_tasks.append(cmd)

    essential_task_ids = list(range(0, len(task_lists)))
    task_executor = execloop.ExpRunner(task_lists + placeholder_tasks, essential_task_ids, parallel_cpus)

    with _active_executors_lock:
        if _shutdown_requested:
            return False
        _active_executors.add(task_executor)
    try:
        task_executor.run()
    finally:
        with _active_executors_lock:
            _active_executors.discard(task_executor)

    # Move all logs to log dir
    for ef in log_files:
        dst_filename = os.path.join(configs.log_dir, ef)
        if os.path.exists(dst_filename):
            log.warning(f"Warning: Log file [{dst_filename}] already exists. Will overwrite!")
            os.unlink(dst_filename)
        src_path = os.path.join(base_temp_dir, ef)
        shutil.move(src_path, configs.log_dir)

    # clean up temp copies and run temp dir
    for ef in temp_sims:
        try:
            os.unlink(ef)
        except OSError:
            pass
    if run_temp_dir is not None:
        try:
            shutil.rmtree(run_temp_dir, ignore_errors=True)
        except OSError:
            pass

    endTime = time.time()
    run_tag = f" [run_{run_index}]" if run_index is not None else ""
    log.info(f"Took {int(endTime - startTime)}s for this test{run_tag}")

    return True




def signal_handler(sig, frame):
    global _shutdown_requested
    with _active_executors_lock:
        if _shutdown_requested:
            return
        _shutdown_requested = True
        snapshot = list(_active_executors)
    if snapshot:
        print("Killing all simulators...", flush=True)
        for ex in snapshot:
            try:
                ex.kill_all()
            except Exception:
                pass
    else:
        print("No simulator running", flush=True)
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)







def _run_one(args):
    run_index, r = args
    sim, design, benchmark, ncpus, iterations = r
    logging.getLogger("Tasks").info(f"Start [run_{run_index}]: {str(r)}")
    run_temp_dir = os.path.join(configs.temp_dir.rstrip(os.sep), f"run_{run_index}")
    try:
        return (run_index, r, run_throughput_test(sim, design, benchmark, ncpus, iterations, run_temp_dir=run_temp_dir, run_index=run_index))
    except Exception as e:
        logging.getLogger("Runner").exception(f"Run {run_index} failed: {e}")
        return (run_index, r, False)
    finally:
        try:
            shutil.rmtree(run_temp_dir, ignore_errors=True)
        except OSError:
            pass


if __name__ == "__main__":

    import settings
    logSetup()

    log = logging.getLogger("Tasks")
    runs = settings.get_throughput_settings()
    max_concurrent = getattr(settings, "max_concurrent_runs", 2)

    for r in runs:
        log.info(f"{str(r)}")
    log.info(f"Total {len(runs)} tasks (max_concurrent_runs={max_concurrent}).")
    log.info("Go!")

    if max_concurrent <= 1:
        for run_index, r in enumerate(runs):
            sim, design, benchmark, ncpus, iterations = r
            log.info(f"Start task [run_{run_index}]: {str(r)}")
            run_temp_dir = os.path.join(configs.temp_dir.rstrip(os.sep), f"run_{run_index}")
            successful = run_throughput_test(sim, design, benchmark, ncpus, iterations, run_temp_dir=run_temp_dir, run_index=run_index)
            try:
                shutil.rmtree(run_temp_dir, ignore_errors=True)
            except OSError:
                pass
            if successful:
                time.sleep(5)
    else:
        with ThreadPoolExecutor(max_workers=max_concurrent) as executor:
            futures = {executor.submit(_run_one, (run_index, r)): run_index for run_index, r in enumerate(runs)}
            for future in as_completed(futures):
                run_index, r, successful = future.result()
                log.info(f"Finished [run_{run_index}]: {str(r)} success={successful}")




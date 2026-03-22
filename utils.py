#!/bin/env python3

import re
import os
import configs
import settings


def parse_exec_cycles(log_filename):
    with open(log_filename) as f:
        for line in f:
            if len(re.findall(r"Completed after \d+ cycles", line)) > 0:
                cycle_count = int(re.findall(r"\d+", line)[0])
                return cycle_count
    return None

suspecious_log_files = []

def parse_exec_time(log_filename):
    key = 'elapsed'
    user_time = 0
    with open(log_filename) as f:
        file_content = f.read().split('\n')
        time_list = file_content[0].split(' ')
        # print(time_list)

        for section in time_list:
            if section.find('user') >= 0:
                user_time = float(section.split('user')[0])
            if section.find(key) >= 0:
                # found
                time_text = section.replace(key, '').strip()
                time_clock = time_text.split(':')
                time_sec = 0
                for index, num in enumerate(reversed(time_clock)):
                    if index == 0:
                        time_sec = float(num)
                    elif index == 1:
                        time_sec += int(num) * 60
                    elif index == 2:
                        time_sec += int(num) * 3600
                    else:
                        print("Error: Unsupported time format: %s" % (time_text))
                        exit(-1)
                if time_sec > user_time * 1.1:
                    # print(log_filename)
                    # print(section)
                    # print(f"Error: Elapsed time ({time_sec}s) is much longer than user time ({user_time}s)! Please check data correctness!")
                    suspecious_log_files.append(log_filename)
                    # exit(-1)
                return user_time
                # return time_sec

def report_rerun_targets():
    ret = []
    for el in suspecious_log_files:
        log_filename = os.path.split(el)[1]
        log_config_raw = ''
        if (log_filename.find('throughput_time_') == 0):
            log_config_raw = log_filename.replace('throughput_time_', '')
        elif log_filename.find('run-cat_time') == 0:
            log_config_raw = log_filename.replace('run-cat_time_', '')
            print(log_filename)
            continue
        else:
            print("Unknow log file type: " + log_filename)
            exit(-1)
        sim, design, bench, ncpu, tails = log_config_raw.split('_')
        ret.append((sim, design, bench, int(ncpu), settings.iterations))
    ret = list(set(ret))
    ret_sorted = list(sorted(ret))

    print("Consider re-run following tests:")
    for er in ret_sorted:
        print(f"{str(er)},")





def get_throughput_data(simulator, design, benchmark_name, parallel_cpus, iterations = 2):

    total_cycles = 0
    total_seconds = 0

    for iter in range(0, iterations):
        for emu_id in range(0, parallel_cpus):
            run_id = iter * parallel_cpus + emu_id
            log_stdout_filename = f"throughput_stdout_{simulator}_{design}_{benchmark_name}_{parallel_cpus}_{run_id}.log"
            log_time_filename = f"throughput_time_{simulator}_{design}_{benchmark_name}_{parallel_cpus}_{run_id}.log"

            log_stdout_filepath = os.path.join(configs.log_dir, log_stdout_filename)
            log_time_filepath = os.path.join(configs.log_dir, log_time_filename)
            
            sim_cycles = 0
            sim_cycles = parse_exec_cycles(log_stdout_filepath)
            sim_seconds = parse_exec_time(log_time_filepath)

            total_cycles += sim_cycles
            total_seconds += sim_seconds

    avg_throughput = total_cycles / (total_seconds / parallel_cpus)

    return avg_throughput


def get_cat_throughput_data(simulator, design, benchmark_name, parallel_cpus, iterations = 2):

    total_cycles = 0
    total_seconds = 0

    for iter in range(0, iterations):
        for emu_id in range(0, parallel_cpus):
            run_id = iter * parallel_cpus + emu_id
            log_stdout_filename = f"cat-throughput_stdout_{simulator}_{design}_{benchmark_name}_{parallel_cpus}_{run_id}.log"
            log_time_filename = f"cat-throughput_time_{simulator}_{design}_{benchmark_name}_{parallel_cpus}_{run_id}.log"

            log_stdout_filepath = os.path.join(configs.log_dir, log_stdout_filename)
            log_time_filepath = os.path.join(configs.log_dir, log_time_filename)
            
            sim_cycles = 0
            sim_cycles = parse_exec_cycles(log_stdout_filepath)
            sim_seconds = parse_exec_time(log_time_filepath)

            total_cycles += sim_cycles
            total_seconds += sim_seconds

    avg_throughput = total_cycles / (total_seconds / parallel_cpus)

    return avg_throughput


def get_avg_completion_time_data(simulator, design, benchmark_name, parallel_cpus, iterations = 2):

    total_seconds = 0

    for iter in range(0, iterations):
        for emu_id in range(0, parallel_cpus):
            run_id = iter * parallel_cpus + emu_id
            log_time_filename = f"throughput_time_{simulator}_{design}_{benchmark_name}_{parallel_cpus}_{run_id}.log"

            log_time_filepath = os.path.join(configs.log_dir, log_time_filename)
            
            sim_seconds = parse_exec_time(log_time_filepath)

            total_seconds += sim_seconds

    return total_seconds / iterations / parallel_cpus



def get_cat_throughput_avg_completion_time_data(simulator, design, benchmark_name, parallel_cpus, iterations = 2):

    total_seconds = 0

    for iter in range(0, iterations):
        for emu_id in range(0, parallel_cpus):
            run_id = iter * parallel_cpus + emu_id
            log_time_filename = f"cat-throughput_time_{simulator}_{design}_{benchmark_name}_{parallel_cpus}_{run_id}.log"

            log_time_filepath = os.path.join(configs.log_dir, log_time_filename)
            
            sim_seconds = parse_exec_time(log_time_filepath)

            total_seconds += sim_seconds

    return total_seconds / iterations / parallel_cpus


# def get_throughput_membw(simulator, design, benchmark_name, parallel_cpus):
#     accumulated_mem_read_bytes = 0
#     accumulated_mem_write_bytes = 0
#     accumulated_exec_time = 0

#     log_filename = f"membw-mon_perf_{simulator}_{design}_{benchmark_name}_{parallel_cpus}.log"
#     log_filepath = os.path.join(configs.log_dir, log_filename)


#     with open(log_filepath) as f:
#         for line in f:
#             if line.find("Bytes") >= 0:
#                 if line.find("llc_misses.mem_read") >= 0:
#                     accumulated_mem_read_bytes += int(line.split("Bytes")[0].strip().replace(',', ''))
#                 elif line.find("llc_misses.mem_write") >= 0:
#                     accumulated_mem_write_bytes += int(line.split("Bytes")[0].strip().replace(',', ''))
#             if line.find('elapsed') >= 0:
#                 accumulated_exec_time += float(line.split('seconds')[0].strip())

#     # MB/s
#     membw_read = (accumulated_mem_read_bytes/1024/1024) / accumulated_exec_time
#     membw_write = (accumulated_mem_write_bytes/1024/1024) / accumulated_exec_time
    
#     return (membw_read, membw_write)
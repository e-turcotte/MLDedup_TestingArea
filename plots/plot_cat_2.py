#!/bin/env python3

import os
import json

import utils
import configs
import settings

from . import plot_configs


import matplotlib as mpl
import matplotlib.pyplot as plt

mpl.rcParams['pdf.fonttype'] = 42
mpl.rcParams['ps.fonttype'] = 42

plot_simulators = [
    "verilator",
    "essent",
    "dedup",
]


figSize = (4,1.7)

x_tick_steps = 3

def plot_cat(design, filename):
    assert(len(settings.monitor_benchmarks) == 1)
    bench = settings.monitor_benchmarks[0]
    design_cores = configs.design_cores[design]
    benchmark = f"{design_cores}t-{bench}"

    platform_info = None
    try:
        platform_info = json.loads(open(f"{configs.log_dir}platform_info.json").read())
    except:
        print("Cannot open platform_info.json. Run measure_cat.py before plot figure 2!")
        return False

    # size in KB
    l3_size = int(platform_info['L3 Size'].replace('K', ''))
    l3_num_ways = int(platform_info['L3 Ways'])
    l3_ways = list(range(1, l3_num_ways + 1))

    

    # title = f"Cache Allocation {design}"
    x_text = "Allocated Cache (MB)"
    y_text = "Time (Seconds)"
    

    figs, axes = plt.subplots(nrows = 1, ncols = 1, figsize = figSize)
    ymax = 0

    # ax for throughput
    ax = axes

    for sim in plot_simulators:
        sim_marker = plot_configs.simulator_markers[sim]
        sim_color = plot_configs.simulator_colors[sim]
        prettyName = configs.simulator_prettyname[sim]
        x_dat = []
        y_dat = []


        for nways in l3_ways:
            try:
                avg_exec_time = 0
                for i in range(0, settings.monitor_iterations):
                    # run-cat_time_verilator_boom21-4mega_4t-vvadd_l3set-10_0.log 
                    log_filename = f"run-cat_time_{sim}_{design}_{benchmark}_l3set-{nways}_{i}.log"
                    log_filepath = os.path.join(configs.log_dir, log_filename)
                    exec_time = utils.parse_exec_time(log_filepath)
                    avg_exec_time += exec_time
                avg_exec_time = avg_exec_time / settings.monitor_iterations

                x_dat.append(nways)
                y_dat.append(avg_exec_time)
                ymax = max(ymax, avg_exec_time)
            except Exception:
                print(f"Unable to get data for {sim} {design} {benchmark} {nways} {settings.iterations}")


        ax.plot(x_dat, y_dat, linestyle='solid', label = prettyName, marker = sim_marker, color = sim_color)

    # ax.set_title(title)
    ax.set_xlabel(x_text)
    ax.set_ylabel(y_text)

    x_tick_text = list(map(lambda x: str(((l3_size / l3_num_ways) * x / 1024)), l3_ways))
    x_ticks = []
    for i, text in enumerate(x_tick_text):
        if i % x_tick_steps == 0:
            x_ticks.append(text)
        else:
            x_ticks.append('')

    ax.set_xticks(l3_ways, labels = x_ticks)

    y_ticks = ax.get_yticks()

    def get_y_tick(num):
        if num == 0.0:
            return "0"
        if num >= 1000_000:
            new_num = int(num / 1000_000)
            if new_num * 1000_000 == num:
                return f"{new_num}M"
            else:
                return "{0:.1f}M".format(num / 1000_000)
        if num >= 1000:
            # new_num = int(num / 1000)
            # print(num)
            # print(new_num)
            # assert new_num * 1000 == num
            new_num = num / 1000
            return f"{new_num}K"
        return str(num)
    y_tick_labels = list(map(get_y_tick, y_ticks))
    ax.set_yticks(y_ticks, y_tick_labels)

    ax.set_xlim(1, l3_num_ways)
    ax.set_ylim(0, ymax * 1.1)
    

    ax.legend(ncols=1)
    # plt.tight_layout()

    plt.subplots_adjust(left=0.14,
                    bottom=0.25, 
                    right=0.95, 
                    top=0.98, 
                    wspace=0.5, 
                    hspace=0.6)

    # plt.show()

    plt.savefig(filename, transparent=True)

    return True





if __name__ == '__main__':
    design = 'boom21-6large'
    bench = 'vvadd'
    design_cores = configs.design_cores[design]
    benchmark = f"{design_cores}t-{bench}"

    filename = f"./cat-{design}.pdf"
    plot_cat(design, benchmark, filename)
    # if not os.path.exists('./plot_cat'):
    #     os.mkdir('./plot_cat')

    # for design in settings.monitor_designs:
    #     for bench in settings.monitor_benchmarks:
    #         design_cores = configs.design_cores[design]
    #         benchmark = f"{design_cores}t-{bench}"

    #         filename = f"./plot_cat/cat-{design}-{benchmark}.pdf"
    #         plot_cat(design, benchmark, filename)
    # utils.report_rerun_targets()

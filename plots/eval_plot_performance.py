#!/bin/env python3

import os

import itertools

import utils
import configs
import settings

from . import plot_configs


import matplotlib as mpl
import matplotlib.pyplot as plt

mpl.rcParams['pdf.fonttype'] = 42
mpl.rcParams['ps.fonttype'] = 42



figSize = (9.1,3)

simulators = configs.simulators

baseline_simulator = "essent"

bar_width = 0.14
design_distance = 1.1
group_spacing = 0.3
dedup_text_x_offset = 0.1

def plot_throughput(filename):

    title = f"Relative simulation speed for all evaluated designs"
    # No x text
    # y_text = "Simulation Speed (Relative)"
    ymax = 0

    assert(settings.tested_designs == list(itertools.chain(*settings.tested_design_groups)))



    # Sample data
    groups = [configs.design_prettyName[design] for design in settings.tested_designs]
    # bars = [configs.simulator_prettyname[sim] for sim in simulators]
    

    # Set up figure and axis
    fig, ax = plt.subplots(figsize = figSize)

    # Define bar width and positions
    bar_positions = []

    current_offset = 0
    for g in settings.tested_design_groups:
        for d in g:
            bar_positions.append(current_offset)
            current_offset += design_distance
        current_offset += group_spacing



    # collect baseline
    baseline_speed = []
    for design in settings.tested_designs:
        design_core_cnt = configs.design_cores[design]
        benchmark = f"{design_core_cnt}t-vvadd"

        throughput = None
        try:
            throughput = utils.get_throughput_data(baseline_simulator, design, benchmark, 1, settings.iterations)
        except Exception:
            pass
        baseline_speed.append(throughput)


    for i, sim in enumerate(simulators):
        sim_color = plot_configs.simulator_colors[sim]
        # For each simulator
        label = configs.simulator_prettyname[sim]
        data = []
        
        baseline_speed_ = []
        for j, design in enumerate(settings.tested_designs):
            design_core_cnt = configs.design_cores[design]
            benchmark = f"{design_core_cnt}t-vvadd"

            if baseline_speed[j] is None:
                # baseline does not exist
                print(f"baseline for {sim} {design} does not exist. Result of all simulators with design {design} will be ignored")
                data.append(0)
                baseline_speed_.append(1)
            else:
                throughput = 0
                try:
                    throughput = utils.get_throughput_data(sim, design, benchmark, 1, settings.iterations)
                except Exception:
                    print(f"Data for {sim} {design} single simulation is missing")
                data.append(throughput)
                baseline_speed_.append(baseline_speed[j])

        # Normalized to baseline
        data = list(map(lambda x: x[0]/x[1], zip(data, baseline_speed_)))
        sim_bar_pos = list(map(lambda x: x + i * bar_width, bar_positions))
        ax.bar(sim_bar_pos, data, width=bar_width, label=label, color = sim_color, linewidth = 0.5, edgecolor='black')
        for j, val in enumerate(data):
            if val == 0:
                # add a marker
                x_xpos = bar_positions[j] + i * bar_width
                x_ypos = 0.05
                ax.plot(x_xpos, x_ypos, 'rx')
        if sim == 'dedup':
            # Add text for dedup bar
            for j, val in enumerate(data):
                if val != 0:
                    design = settings.tested_designs[j]
                    design_core_cnt = configs.design_cores[design]
                    benchmark = f"{design_core_cnt}t-vvadd"

                    max_abs_throughput = 0
                    for sim in simulators:
                        throughput = 0
                        try:
                            throughput = utils.get_throughput_data(sim, design, benchmark, 1, settings.iterations)
                        except Exception:
                            print(f"Data for {sim} {design} single simulation is missing")

                        max_abs_throughput = max(max_abs_throughput, throughput)
                    max_relative_throughput = max_abs_throughput / baseline_speed[j]

                    text = "{0:.3f}".format(val)
                    ax.text(bar_positions[j] + i * bar_width - dedup_text_x_offset, max_relative_throughput - 0.07, text, ha='center', va='bottom', fontsize = 11, rotation = 30)

        ymax = max(ymax, max(data))

    # Set labels, title, and legend
    x_tick_pos = list(map(lambda x: x + ((len(simulators) - 1) * bar_width / 2), bar_positions))
    ax.set_xticks(x_tick_pos)
    ax.set_xticklabels(groups, rotation=30, ha='right', fontsize = 11)

    y_ticks = ax.get_yticks()
    y_tick_labels = list(map(lambda x: "{0:.1f}".format(x) if x != 0.0 else '0', y_ticks))
    ax.set_yticks(y_ticks, y_tick_labels, fontsize = 11)
    # ax.set_xlabel('Groups')
    # ax.set_ylabel(y_text)
    # ax.set_title(title)
    ax.set_ylim(0, ymax * 1.35)
    ax.set_xlim(-0.25, max(bar_positions) + 1.35)
    ax.legend(loc='upper left', ncol=len(simulators), fontsize = 11, mode="expand")

    ax.axhline(y=1, color='r', linestyle='--')

    # plt.tight_layout()

    plt.subplots_adjust(left=0.06,
                    bottom=0.26, 
                    right=0.982, 
                    top=0.98, 
                    wspace=0.1, 
                    hspace=0.1)

    # Show the plot
    # plt.show()

    plt.savefig(filename, transparent = True)





if __name__ == '__main__':

    plot_throughput("eval_simulator_performance.pdf")
    utils.report_rerun_targets()

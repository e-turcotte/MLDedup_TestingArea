#!/bin/env python3

import os

import utils
import configs
import settings

from . import plot_configs


import matplotlib as mpl
import matplotlib.pyplot as plt

mpl.rcParams['pdf.fonttype'] = 42
mpl.rcParams['ps.fonttype'] = 42



figSize = (10,6)
base_fontsize = 11.5

simulators = configs.simulators



subfigure_layout = [
    ['rocket21-1c', 'rocket21-2c', 'rocket21-4c', 'rocket21-6c', 'rocket21-8c'],
    ['boom21-small', 'boom21-2small', 'boom21-4small', 'boom21-6small', 'boom21-8small'],
    ['boom21-large', 'boom21-2large', 'boom21-4large', 'boom21-6large', 'boom21-8large'],
    ['boom21-mega', 'boom21-2mega', 'boom21-4mega', 'boom21-6mega', 'boom21-8mega'],
]

def plot_throughput(filename):

    title = f"Relative simulation speed for all evaluated designs"
    # No x text
    x_text = "# of parallel simulations"
    y_text = "Throughput (Simulation Speed (Hz)/Server)"


    # Set up figure and axis
    fig, axes = plt.subplots(nrows = len(subfigure_layout), ncols=len(subfigure_layout[0]), figsize = figSize)

    for fig_y, row_layout in enumerate(subfigure_layout):
        # ymax = 0
        for fig_x, design in enumerate(row_layout):
            ax = axes[fig_y, fig_x]

            if design == 'None':
                # legend_sequence = [
                #     'Commercial', 
                #     'Verilator', 
                #     'ESSENT', 
                #     'Dedup', 
                #     'PO', 
                #     'NL',
                #     ]
                pass

                # ax.set_xticks([])
                # ax.set_yticks([])
            else:
                # A normal design
                design_core_cnt = configs.design_cores[design]
                design_prettyName = configs.get_design_pretty_name(design)
                benchmark = f"{design_core_cnt}t-vvadd"

                
                ymax = 0

                statistic_data = {}

                for i, sim in enumerate(simulators):
                    sim_marker = plot_configs.simulator_markers[sim]
                    sim_color = plot_configs.simulator_colors[sim]

                    sim_linestyle = plot_configs.simulator_linestyle[sim]
                    parallel_cpus = settings.parallel_cpus
                    sim_prettyName = configs.simulator_prettyname[sim]
                    x_dat = []
                    y_dat = []

                    title = f"{design_prettyName}"

                    for ncpu in parallel_cpus:
                        try:
                            throughput = utils.get_throughput_data(sim, design, benchmark, ncpu, settings.iterations)

                            x_dat.append(ncpu)
                            # y_dat.append(relative_throughput)
                            # ymax = max(ymax, relative_throughput)
                            y_dat.append(throughput)
                            ymax = max(ymax, throughput)
                        except Exception as e:
                            print(f"Unable to get data for {sim} {design} {benchmark} {ncpu} {settings.iterations}")
                            # exit(-1)
                    ax.plot(x_dat, y_dat, linestyle=sim_linestyle, label = sim_prettyName, marker = sim_marker, color = sim_color)

                    statistic_data[sim] = y_dat

                ax.set_xlim(min(settings.parallel_cpus), max(settings.parallel_cpus))
                ax.set_ylim(0, ymax * 1.1)

                ax.set_title(title, fontsize = base_fontsize+1)
                # if fig_y == len(subfigure_layout) - 1:
                #     ax.set_xlabel(x_text)
                x_ticks = settings.parallel_cpus
                x_tick_labels = []
                for i, tick in enumerate(x_ticks):
                    if i % 2 == 0:
                        x_tick_labels.append(str(int(tick)))
                    else:
                        x_tick_labels.append('')
                ax.set_xticks(x_ticks, x_tick_labels, fontsize = base_fontsize)
                y_ticks = ax.get_yticks()

                def get_y_tick(num):
                    if num == 0.0:
                        return "0"
                    if num >= 1000_00:
                        new_num = int(num / 1000_000)
                        if new_num * 1000_000 == num:
                            return f"{new_num}M"
                        else:
                            return "{0:.1f}M".format(num / 1000_000)
                    if num >= 100:
                        new_num = int(num / 1000)
                        assert new_num * 1000 == num
                        return f"{new_num}K"
                    return str(num)
                y_tick_labels = list(map(get_y_tick, y_ticks))
                # print(y_tick_labels)
                ax.set_yticks(y_ticks, y_tick_labels, fontsize = base_fontsize)
                # if fig_x == 0:
                #     ax.set_ylabel(y_text)
                # if y_id == 0:
                #     ax.set_ylabel(y_text)
                #     ax2.set_yticks([])
                # if y_id == 1:
                #     ax2.set_ylabel(y_text2)
                #     ax.set_yticks([])

                # print dedup vs essent throughput

                if len(statistic_data['dedup']) > 0 and len(statistic_data['essent']) > 0:
                    max_x = max(statistic_data['dedup']) / max(statistic_data['essent'])
                    print(f"Dedup vs essent, {design}: best {max_x}x throughput")





                # if fig_x == len(subfigure_layout[fig_y]) - 1:
                #     for i in range(0, len(subfigure_layout[fig_y])):
                #         axes[fig_y, i].set_ylim(0, ymax * 1.1)
    # plt.tick_params(labelcolor='none', which='both', top=False, bottom=False, left=True, right=False)
                
    legend_sequence = [
        'Dedup', 
        'NL', 
        'PO', 
        'ESSENT', 
        'Verilator', 
        'Verilator - NoDedup',
        'Commercial',
        ]
    lines, labels = axes[0, 0].get_legend_handles_labels()
    handle_dict = {}
    for line, label in zip(lines, labels):
        handle_dict[label] = line
    line_sequence = []
    for label in legend_sequence:
        line_sequence.append(handle_dict[label])
    # print(labels)
    ax.legend(line_sequence, legend_sequence, handletextpad = 0.5, ncols = len(legend_sequence),loc='center', fontsize = base_fontsize, bbox_to_anchor = (-2.45, -0.55))
    # ax.axis('off')

    fig.supxlabel(x_text, fontsize = base_fontsize+1)
    fig.supylabel(y_text, fontsize = base_fontsize + 1)


    # plt.tight_layout()

    plt.subplots_adjust(left=0.09,
                    bottom=0.15, 
                    right=0.98, 
                    top=0.95, 
                    wspace=0.35, 
                    hspace=0.65)

    # plt.show()

    plt.savefig(filename, transparent=True)





if __name__ == '__main__':

    plot_throughput("eval_simulator_throughput.pdf")
    utils.report_rerun_targets()

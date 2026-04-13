"""
Paper figure generator. Run from the repo root:
    python3 -m analysis.generate_paper_figures
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "execution"))

import configs
from analysis import plot_figure8, plot_figure9

# Figure 8
plot_figure8.plot_throughput("Figure8.pdf")

# Figure 9
plot_figure9.plot_throughput("Figure9.pdf")

# Figure 2 (optional; requires measure_cat.py and platform_info.json)
if os.path.isfile(f"{configs.log_dir}platform_info.json"):
    from analysis import plot_figure2
    plot_figure2.plot_cat("boom21-6large", "Figure2.pdf")



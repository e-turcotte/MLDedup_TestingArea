

# Figure 8
import plots.eval_plot_performance

plots.eval_plot_performance.plot_throughput("Figure8.pdf")

# Figure 9
import plots.eval_plot_throughput
plots.eval_plot_throughput.plot_throughput("Figure9.pdf")

# Figure 2 (optional; requires measure_cat.py and platform_info.json)
import os
import configs
if os.path.isfile(f"{configs.log_dir}platform_info.json"):
    import plots.plot_cat_2
    plots.plot_cat_2.plot_cat("boom21-6large", 'Figure2.pdf')



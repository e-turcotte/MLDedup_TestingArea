# [Artifact] Don't Repeat Yourself! Coarse-Grained Circuit Deduplication to Accelerate RTL Simulation

  

This package contains the artifact for of *Don't Repeat Yourself! Coarse-Grained Circuit Deduplication to Accelerate RTL Simulation*. This package also contains script to plot figure 2, 8 and 9, which are main result of this paper. Figure 1, 10, 12 are special case of figure 9 and thus script is not provided. 

Due to platform variance (different performance counters on different platform), we are unable to provide script involving collecting data by `perf` in a portable way.

  

This artifact contains the source code for our deduplication code, as well as other open source projects that are required to reproduce the results in the paper. We include Verilator 5.016 as a baseline. In addition, this artifact also contains scripts and a Makefile to compile and run the generated simulators, as well as to reproduce figures from experimental data.


To quickly verify/reproduce result in the paper, this package allows user to selectively run partial simulators. Users can reproduce key results in few days. **Fully reproduce every data point in this paper may take around 1 month, Please be careful when choosing simulators to test!** We recommend test `simulator_rocket21-1c simulator_boom21-6large` that completes in few days (depending on number of cores). 


  

# 0 Resource Requirements

1. Multicore x86 machine to test simulation throughput (Figure 8 and 9).

2. (Optional) Intel Cache Allocation Technology/Intel Resource Director Technology/AMD Platform Quality of Service Extension required to reproduce Figure 2. ***root access on physical machine (not docker) is also required to reproduce Figure 2**.

    + Scripts is tested under Intel 2nd gen Xeon (Cascade Lake), Intel 3rd gen Xeon (Ice Lake) and AMD Zen 3 desktop processors.

3. OS: Linux (Debian/Ubuntu recommended and tested)

4. Sufficient memory to build simulators

    + ~`80GB` of peak memory when `make -j5 simulator_rocket21-1c simulator_boom21-6large simulator_boom21-6small`
    + We recommend reserve ~`20GB` of memory for each parallel build CPUs.

4. Sufficient disk space. We recommend using SSD for better disk performance

    + Build and test EVERY simulator requires ~`80GB` disk space.

5. Internet connection

6. Estimated build time: 

	+ ~`1 hour` is required to prepare the build environment if `make -j12`. ~`15 minutes` if `make -j60`
    + Build time of simulators depends on designs. Small designs like `rocket21-1c` may require around `10 minutes`, large designs like `boom21-6large` consumes ~`8 hours`.
    + We recommend try only few designs to speed up reproduce process.

7. Estimated simulation time: 

Ranging from `1 day` to ~`1 month`, depending on configuration. `simulator_rocket21-1c simulator_boom21-6large` testing for `1, 4, 8, 12` cores takes around 1 day.

  

# 1 Software Dependencies


+ Simulator dependencies (on Debian/Ubuntu): `build-essential wget time git autoconf flex bison help2man perl python3 make unzip device-tree-compiler python3-psutil sbt`. Java environment is also required, and can be provided by `openjdk-17-jdk`
  

+ Data processing: `python3` is needed to process data and produce figures. Python package `matplotlib` is required.


+ If you wish to reproduce Figure 2, please install `intel-cmt-cat numactl` and make sure you have **root access**.

  

To install all dependencies (except `sbt`, please follow [guide here](https://www.scala-sbt.org/1.x/docs/Installing-sbt-on-Linux.html) ) on Ubuntu:

```
sudo apt install build-essential git autoconf flex bison help2man perl make wget unzip time
sudo apt install openjdk-17-jdk python3-matplotlib python3-psutil device-tree-compiler
# Optional, Figure 2 only
sudo apt install intel-cmt-cat numactl
```


# 2 Open Source Projects

This artifact uses several open-source projects. Specifically, the following 2 projects are used to generate benchmark designs:


+  `rocket-chip`: [Rocket Chip Generator](https://github.com/chipsalliance/rocket-chip.git), commit `4276f17f989b99e18e0376494587fe00cd09079f`

+  `boom-standalone`: [BOOM](https://github.com/riscv-boom/riscv-boom) is an open-source OoO RISC-V core used by this paper's evaluation. BOOM itself is not a self-running project. We run BOOM using `rocket-chip`'s IO and debug port (See [this repo](https://github.com/haoozi/boom-standalone), commit `4276f17f989b99e18e0376494587fe00cd09079f`)


Other open-source projects to run the simulator:

+ `firrtl`: Convert `chisel` generated FIRRTL file to Verilog. [FIRRTL](https://github.com/chipsalliance/firrtl.git), commit `a6851b8ec4044eef4af759a21887fdae6226e1cd`

+ `riscv-isa-sim`: We use `fesvr` in [riscv-isa-sim](https://github.com/riscv-software-src/riscv-isa-sim.git) to create simulators. commit `ddcfa6cc3d80818140a459e590296c3079c5a3ec`, `68b3eb9bf1c04c19a66631f717163dd9ba2c923c`

+ `firrtl-sig`: C++ library that provides UInt and SInt from FIRRTL spec. [firrtl-sig](git@github.com:ucsc-vama/firrtl-sig.git), commit `4504848ad436c172ca997142b2744926421c4f66`

Thanks for all of the contributions from the open-source community!

  

# 3 Package Content

This AE package contains the following directories:

**We use environment variable `PKGROOT` to denote the root directory of this artifact.**
  

+  `$(PKGROOT)/log/`: log files

+  `$(PKGROOT)/mt-benchmarks/`: benchmark binary files.

+  `$(PKGROOT)/plots/`: plotting script.

+  `$(PKGROOT)/essent/`:  
    + `$(PKGROOT)/master/` [ESSENT](https://github.com/ucsc-vama/essent) master branch
    + `$(PKGROOT)/dedup/` ESSENT with deduplication
    + `$(PKGROOT)/dedup-nl/` ESSENT with deduplication, no locality optimization
    + `$(PKGROOT)/po/` ESSENT with modified partitioner but no deduplication code generation

+  `$(PKGROOT)/essent-master/`: Project directory for ESSENT

+  `$(PKGROOT)/verilator/`: Project directory for verilator

Scripts:

+ `$(PKGROOT)/expand_files.sh` Prepare project direcoty.

+ `$(PKGROOT)/measure_throughput.py` Run throughput test, save log file to `$(PKGROOT)/log/`

+ `$(PKGROOT)/measure_cat.py` Run test with cache allocation. This script generates data for figure 2, and require root priviledge.

+ `$(PKGROOT)/plot.py` Plotting.

+ `$(PKGROOT)/settings.py` Configuration of parallel tasks, benchmark and designs for both measurement and plotting.


# 4 Compilation Guide: Before Start


Before compilation, please check following items:

## 4.1 Set Compiler (Optional)

Modify Makefile if prefer different compiler

```
# Default compiler is g++

CXX := g++
LINK := g++
AR := ar
```
  
We observe certain version of g++ may throw Internal Compiler Error on large design (for example, boom21-8mega). 
  

## 4.2 Configure Number of Parallel Simulations



This artifact is configured to compile and run for `1, 4, 8, 12` parallel simulations. Please adjust this configuration base on your platform and time budget.

Tips: 
1. `1` should always be included. Figure 8 demonstrates performance when parallelism = 1. 
2. We recommend include the number of your physical CPU.
3. Measurement script will run each simulators for every parallelism in this list. More numbers leads to slower simulation time. We recommend a larger step size.

  
You may change parallel simulation by modifying `$(PKGROOT)/settings.py`:

  

```
# Line 13
parallel_cpus = [1, 4, 8, 12]
```

## 4.3 Set Design for Figure 2 (Optional)

If you wish to reproduce Figure 2 but with different design, You can change the design to collect data by modifying `$(PKGROOT)/settings.py`:

```
# Line 21
monitor_designs = ["boom21-6large"]
```

And also plotting script `$(PKGROOT)/plot.py`:
```
# Line 14, change design name from "boom21-6large" to any design you desinate
plots.plot_cat_2.plot_cat("boom21-6large", Figure2.pdf')
```

Available design list can be found in section 6.

# 5 Compilation Guide: Prepare


This step creates build directory and compiles necessary dependencies.


```
cd $(PKGROOT)/
bash ./expand_files.sh
make -j<N> prepare
```

  

Suggestion of parallelism `<N>`: 20 or more

Max. memory requirement: <`10 GB` using `make -j32`

Typical time: 13 mins using `make -j60`, ~ 1 hour using `make -j12`




# 6 Compilation Guide: Build Simulators



This artifact contains following designs:

|Name| Description |
|--|--|
| rocket21-1c | Single core Rocket Chip |
| rocket21-2c | Dual core Rocket Chip |
| rocket21-4c | Quad core Rocket Chip |
| rocket21-6c | Hexa core Rocket Chip |
| rocket21-8c | Octa core Rocket Chip |
| boom21-small | Single core Small Boom |
| boom21-2small | Dual core Small Boom |
| boom21-4small | Quad core Small Boom |
| boom21-6small | Hexa core Small Boom |
| boom21-8small | Octa core Small Boom |
| boom21-large | Single core Large Boom |
| boom21-2large | Dual core Large Boom |
| boom21-4large | Quad core Large Boom |
| boom21-6large | Hexa core Large Boom |
| boom21-8large | Octa core Large Boom |
| boom21-mega | Single core Mega Boom |
| boom21-2mega | Dual core Mega Boom |
| boom21-4mega | Quad core Mega Boom |
| boom21-6mega | Hexa core Mega Boom |
| boom21-8mega | Octa core Mega Boom |



Option A (recommended): build simulators for selected design:
```
# `Make` target name:
# simulator_<design>
# Example: build rocket21-6c and boom21-2small
cd $(PKGROOT)/
make -j<N> simulator_rocket21-6c simulator_boom21-2small
```

Again, build all simulators is not necessary for artifact evaluation, as few selected data points are sufficient to reproduce the result. We recommend test `simulator_rocket21-1c` (a typical small design) and `simulator_boom21-6large` (a typical large design) that can be built in around 1 day, and finish measurement in 1~2 days (depending on number of cores). You can also randomly select few extra designs.

Option B: Build all simulators (**This is NOT necessary and may take few days!**):

```
cd $(PKGROOT)/
make -j<N> simulator_all
```

Suggestion of parallelism `<N>`: All ESSENT-based simulators doesn't support parallel compilation, but requires large memory. We recommend set `<N>` base on available memory. Our practice is reserve ~`20GB` memory for each build process. Example: `<N>` can be `5` if `128GB` memory in total. Larger designs requires more memory.


# 7 Run Simulation

## 7.1 Measure throughput

To measure throughput/performance for all built simulators:

```
cd $(PKGROOT)/
python3 ./measure_throughput.py
```

This script automatically find available simulator binary files and measure throughput and performance. Completion time depends on built simulators (See section 6) and configuration (See section 4.2).

## 7.2 Measure Performance with Cache Allocation Technology (Figure 2, optional)

To reproduce Figure 2, collect data by:

```
cd $(PKGROOT)/
# load msr kernel module
sudo modprobe msr
sudo python3 ./measure_cat.py <core_id>
```

`<core_id>` is the core to pin the simulator. core `1` would be a good choice if no other reason.


# 8 Obtain Figures and Tables

After all data is ready, get plots by
```
cd $(PKGROOT)/
# This script generates Figure8.pdf, Figure9.pdf and Figure2.pdf under $(PKGROOT)
python3 ./plot.py
```


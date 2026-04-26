

base_dir=$(abspath .)
benchmark_dir=$(base_dir)/riscv-benchmarks-bin
build_dir=$(base_dir)/build
output_dir=$(base_dir)/emulator
log_dir=$(base_dir)/log

RUN_BENCHMARK = $(benchmark_dir)/dhrystone.riscv

CXX = g++
LINK = g++
AR = ar


# Designs to compile
DESIGNS = \
	rocket21-1c \
	rocket21-2c \
	rocket21-4c \
	rocket21-6c \
	rocket21-8c \
	boom21-small \
	boom21-2small \
	boom21-4small \
	boom21-6small \
	boom21-8small \
	boom21-large \
	boom21-2large \
	boom21-4large \
	boom21-6large \
	boom21-8large \
	boom21-mega \
	boom21-2mega \
	boom21-4mega \
	boom21-6mega \
	boom21-8mega \


# Compile essent
ESSENT_JAR = essent.jar
# When non-empty, install emulator as emulator_essent_<design>_r<ESSENT_RANK> (and matching essent log).
ESSENT_RANK ?=

# Optional optimization-level override for the C++ compile step.
# When set (e.g. CXX_OPT=-O1) we forward an explicit CXXFLAGS to the per-design
# sub-make so cc1plus does not OOM at -O3 on the giant generated TestHarness.h.
# Passing CXXFLAGS on the command line replaces the value defined in
# Makefrag-variables.mk, so we have to reconstruct the include paths.
CXX_OPT ?=

MAKE_VARIABLES = ESSENT_JAR=$(ESSENT_JAR) CXX=$(CXX) LINK=$(LINK) AR=$(AR)


PREPARE_TARGETS = $(addprefix prepare_,$(DESIGNS))

${PREPARE_TARGETS}: prepare_%: $(FIRRTL_JAR)
	$(MAKE) -C $* -f Makefile-prepare.mk $(MAKE_VARIABLES) all
	$(MAKE) -C $* -f Makefile-emulator.mk $(MAKE_VARIABLES) riscv/lib/libfesvr.a
	cd $(base_dir)/$* && rm -rf riscv/bin/
	cd $(base_dir)/$* && rm -rf riscv/lib/libcustomext.so riscv/lib/libdisasm.a riscv/lib/libsoftfloat.so
	mkdir -p $(build_dir)/$*; cd $(base_dir)/$* && cp -r `ls -A | grep -v "riscv-isa-sim"` $(build_dir)/$*;



design = $(firstword $(subst _, ,$*))


# ESSENT compile
COMPILE_EMULATOR_ESSENT_TARGETS := $(foreach i,$(DESIGNS),compile_essent_$i)

${COMPILE_EMULATOR_ESSENT_TARGETS}: compile_essent_%:
	rm -f $(build_dir)/$(design)/TestHarness.h $(build_dir)/$(design)/dedup_features.csv $(build_dir)/$(design)/emulator_essent
	$(MAKE) -C $(build_dir)/$(design) -f Makefile-emulator.mk $(MAKE_VARIABLES) \
		$(if $(strip $(CXX_OPT)),CXXFLAGS="$(CXX_OPT) -std=c++17 -I$(build_dir)/$(design)/riscv/include -D__STDC_FORMAT_MACROS",) \
		emulator_essent
	@if [ -n "$(strip $(ESSENT_RANK))" ]; then \
		cp $(build_dir)/$(design)/emulator_essent $(output_dir)/emulator_essent_$(design)_r$(ESSENT_RANK); \
		cp $(build_dir)/$(design)/essent.log $(log_dir)/essent_$(design)_r$(ESSENT_RANK).log; \
		cp $(build_dir)/$(design)/dedup_features.csv $(log_dir)/dedup_features_$(design)_r$(ESSENT_RANK).csv; \
	else \
		cp $(build_dir)/$(design)/emulator_essent $(output_dir)/emulator_essent_$(design); \
		cp $(build_dir)/$(design)/essent.log $(log_dir)/essent_$(design).log; \
		cp $(build_dir)/$(design)/dedup_features.csv $(log_dir)/dedup_features_$(design).csv; \
	fi


CLEAN_ESSENT_TARGETS := $(foreach j,$(DESIGNS),clean_essent_$j)

${CLEAN_ESSENT_TARGETS}: clean_essent_%:
	$(MAKE) -C $(build_dir)/$(design) -f Makefile-emulator.mk $(MAKE_VARIABLES) clean_emulator_essent






.PHONY: $(PREPARE_TARGETS) $(COMPILE_EMULATOR_ESSENT_TARGETS) emulator_essent all clean prepare clean_essent

prepare: $(PREPARE_TARGETS)
	mkdir -p $(output_dir)
	mkdir -p $(log_dir)

emulator_essent: $(COMPILE_EMULATOR_ESSENT_TARGETS)



# Default
all: emulator_essent

clean_essent: $(CLEAN_ESSENT_TARGETS)

clean: clean_essent

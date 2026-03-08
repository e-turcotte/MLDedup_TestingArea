

base_dir=$(abspath .)
benchmark_dir=$(base_dir)/riscv-benchmarks-bin
build_dir=$(base_dir)/build
output_dir=$(base_dir)/emulator
log_dir=$(base_dir)/log

essent_dir=$(base_dir)/essent

RUN_BENCHMARK = $(benchmark_dir)/dhrystone.riscv

CXX = g++-11
LINK = g++-11
AR = gcc-ar-11


# Designs to compile

# rocket21-8c \
# boom21-8small \
# boom21-8large \
# boom21-8mega \

DESIGNS = \
	rocket21-8c \
	rocket21-4c \


# Compile essent
ESSENT_JAR = $(essent_dir)/utils/bin/essent.jar





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
	$(MAKE) -C $(build_dir)/$(design) -f Makefile-emulator.mk $(MAKE_VARIABLES) emulator_essent
	cp $(build_dir)/$(design)/emulator_essent $(output_dir)/emulator_essent_$(design)
	cp $(build_dir)/$(design)/essent.log $(log_dir)/essent_$(design).log


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

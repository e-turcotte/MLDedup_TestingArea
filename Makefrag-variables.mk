include Makefrag-source-files.mk
include Makefrag-JVMflags.mk



CXX = clang++
LINK = clang++
AR = ar

#########################################################################################
# check environment variable
#########################################################################################
ifndef FIRRTL_BIN
$(error Please set environment variable FIRRTL_BIN.)
endif

ifndef INSTALLED_VERILATOR
$(error Please set environment variable INSTALLED_VERILATOR.)
endif

ifndef ESSENT_JAR
$(error Please set environment variable ESSENT_JAR.)
endif



MODEL = TestHarness

VERILOG_FILE_PATH = $(base_dir)/$(MODEL).v

model_dir = $(base_dir)/$(MODEL)
model_mk = $(model_dir)/V$(MODEL).mk
model_header = $(model_dir)/V$(MODEL).h





riscv_dir := $(shell pwd)/riscv
ESSENT_INCLUDES = -Iriscv/include -I./firrtl-sig
LIBS = -L$(riscv_dir)/lib -Wl,-rpath,$(riscv_dir)/lib -lfesvr -lpthread




CXXFLAGS = -O3 -std=c++17 -I$(riscv_dir)/include -D__STDC_FORMAT_MACROS
CLANG_FLAGS = -fno-slp-vectorize -fbracket-depth=4096

UNAME_OS := $(shell uname -s)
ifeq ($(UNAME_OS),Darwin)
	CXXFLAGS += $(CLANG_FLAGS)
endif



sim_vsrcs = \
	$(VERILOG_FILE_PATH) \
	$(base_dir)/vsrc/AsyncResetReg.v \
	$(base_dir)/vsrc/EICG_wrapper.v \
	$(base_dir)/vsrc/plusarg_reader.v \

sim_csrcs = \
	$(base_dir)/csrc/SimDTM.cc \
	$(base_dir)/csrc/SimJTAG.cc \
	$(base_dir)/csrc/remote_bitbang.cc \
	$(base_dir)/csrc/emulator_verilator.cc \


emulator_verilator = $(base_dir)/emulator_verilator


# Run Verilator to produce a fast binary to emulate this circuit.
VERILATOR := $(INSTALLED_VERILATOR) --cc --exe
VERILATOR_FLAGS := --top-module $(MODEL) \
  +define+PRINTF_COND=\$$c\(\"verbose\",\"\&\&\"\,\"done_reset\"\) \
  +define+STOP_COND=\$$c\(\"done_reset\"\) --assert \
  --output-split 20000 \
  -Wno-fatal \
  -fno-dedup \
  --no-threads \
  -Wno-STMTDLY --x-assign unique \
  -I$(base_dir)/vsrc -I$(base_dir)/rocket-chip/src/main/resources/vsrc \
  -O3 -CFLAGS "$(CXXFLAGS) -DVERILATOR -DTEST_HARNESS=V$(MODEL) -include $(base_dir)/csrc/verilator.h -include $(PLUSARGS_PATH)" \


include Makefrag-JVMflags.mk
include Makefrag-source-files.mk




CXX = clang++
LINK = clang++
AR = ar

#########################################################################################
# check environment variable
#########################################################################################
ifndef ESSENT_JAR
$(error Please set environment variable ESSENT_JAR.)
endif




riscv_dir := $(shell pwd)/riscv
ESSENT_INCLUDES = -Iriscv/include -I./firrtl-sig
LIBS = -L$(riscv_dir)/lib -Wl,-rpath,$(riscv_dir)/lib -lfesvr -lpthread




CXXFLAGS = -O3 -std=c++17 -I$(riscv_dir)/include -D__STDC_FORMAT_MACROS
CLANG_FLAGS = -fno-slp-vectorize -fbracket-depth=4096

UNAME_OS := $(shell uname -s)
ifeq ($(UNAME_OS),Darwin)
	CXXFLAGS += $(CLANG_FLAGS)
endif




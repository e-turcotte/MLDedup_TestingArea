include Makefrag-variables.mk

RISCV_ISA_SIM_REPO ?= https://github.com/riscv-software-src/riscv-isa-sim.git


$(FIR_PATH):
	tar -xvf ./firrtl.tar.gz


.PHONY: all clean

all: $(FIR_PATH)
	test -d riscv-isa-sim/.git || git clone -q -- "$(RISCV_ISA_SIM_REPO)" riscv-isa-sim
	cd riscv-isa-sim && (git fetch -q --tags 2>/dev/null || true) && git checkout $$(cat ../riscv-isa-sim.commit)

clean:
	rm $(FIR_PATH)

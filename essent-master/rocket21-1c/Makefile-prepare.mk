include Makefrag-variables.mk


$(FIR_PATH):
	tar -xvf ./firrtl.tar.gz


.PHONY: all clean

# Use upstream riscv-isa-sim; clone if missing or not a real clone (e.g. empty dir inherits parent git)
RISCV_ISA_SIM_UPSTREAM := https://github.com/riscv-software-src/riscv-isa-sim.git
RISCV_REF := $(shell cat riscv-isa-sim.commit)
all: $(FIR_PATH)
	@if [ ! -f riscv-isa-sim/configure ] && [ ! -d riscv-isa-sim/.git/refs ]; then \
	  rm -rf riscv-isa-sim && git clone --depth 1 --branch $(RISCV_REF) $(RISCV_ISA_SIM_UPSTREAM) riscv-isa-sim; \
	else \
	  cd riscv-isa-sim && \
	    (git remote get-url origin 2>/dev/null | grep -q riscv-isa-sim || git remote set-url origin $(RISCV_ISA_SIM_UPSTREAM)) && \
	    git fetch origin tag $(RISCV_REF) 2>/dev/null || true && \
	    git checkout $$(cat ../riscv-isa-sim.commit); \
	fi

clean:
	rm $(FIR_PATH)

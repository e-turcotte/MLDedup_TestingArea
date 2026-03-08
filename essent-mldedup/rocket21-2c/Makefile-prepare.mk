include Makefrag-variables.mk


$(FIR_PATH):
	tar -xvf ./firrtl.tar.gz


.PHONY: all clean

all: $(FIR_PATH) 
	cd riscv-isa-sim; git checkout `cat ../riscv-isa-sim.commit`

clean:
	rm $(FIR_PATH)

#!/bin/bash

#use to handle the submodules if they ever get weird

declare -a DESIGNS=("rocket21-1c" "rocket21-2c" "rocket21-4c" "rocket21-6c" "rocket21-8c" "boom21-small" "boom21-2small" "boom21-4small" "boom21-6small" "boom21-8small" "boom21-large" "boom21-2large" "boom21-4large" "boom21-6large" "boom21-8large" "boom21-mega" "boom21-2mega" "boom21-4mega" "boom21-6mega" "boom21-8mega")

for d in "${DESIGNS[@]}"; do
	rm -rf essent-$1/$d/riscv-isa-sim
	git clone https://github.com/riscv-software-src/riscv-isa-sim.git essent-$1/$d/riscv-isa-sim
done

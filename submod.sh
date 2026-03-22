#!/bin/bash
# Clone riscv-isa-sim into each design dir if missing or not a valid clone.
# Usage: ./submod.sh <mldedup|master>
# Only clones when the repo does not exist or lacks .git/configure.

DESIGNS="rocket21-1c rocket21-2c rocket21-4c rocket21-6c rocket21-8c boom21-small boom21-2small boom21-4small boom21-6small boom21-8small boom21-large boom21-2large boom21-4large boom21-6large boom21-8large boom21-mega boom21-2mega boom21-4mega boom21-6mega boom21-8mega"
REPO="https://github.com/riscv-software-src/riscv-isa-sim.git"

for d in $DESIGNS; do
	dir="essent-$1/$d/riscv-isa-sim"
	if [ -f "$dir/configure" ] || [ -d "$dir/.git/refs" ]; then
		echo "Skipping $dir (already exists)"
		continue
	fi
	rm -rf "$dir"
	git clone "$REPO" "$dir"
done

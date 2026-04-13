#!/usr/bin/env bash
# Clone riscv-isa-sim into each design dir if missing or not a valid clone,
# then check out the pin in <design>/riscv-isa-sim.commit (same as Makefile-prepare.mk).
#
# Usage: ./submod.sh <mldedup|master>
# Run from anywhere; paths are resolved relative to this script.
#
# Overlap: essent-mldedup/*/Makefile-prepare.mk also clones if .git is missing.
# Use this script for a one-shot bulk init before running make/sweeps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DESIGNS="rocket21-1c rocket21-2c rocket21-4c rocket21-6c rocket21-8c boom21-small boom21-2small boom21-4small boom21-6small boom21-8small boom21-large boom21-2large boom21-4large boom21-6large boom21-8large boom21-mega boom21-2mega boom21-4mega boom21-6mega boom21-8mega"
REPO="https://github.com/riscv-software-src/riscv-isa-sim.git"

for d in $DESIGNS; do
	parent="essent-$1/$d"
	dir="$parent/riscv-isa-sim"
	commit_file="$parent/riscv-isa-sim.commit"
	if [ -f "$dir/configure" ] || [ -d "$dir/.git/refs" ]; then
		echo "Skipping $dir (already exists)"
		continue
	fi
	rm -rf "$dir"
	git clone -q -- "$REPO" "$dir"
	if [ -f "$commit_file" ]; then
		(git -C "$dir" fetch -q --tags 2>/dev/null || true)
		git -C "$dir" checkout "$(tr -d '\r\n' <"$commit_file")"
	fi
done

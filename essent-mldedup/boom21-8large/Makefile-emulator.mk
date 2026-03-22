include Makefrag-variables.mk



# build fesvr
riscv/lib/libfesvr.a:
	mkdir -p $(riscv_dir)
	cd riscv-isa-sim && (grep -q '<cstdint>' fesvr/device.h || sed -i '/#include <functional>/a#include <cstdint>' fesvr/device.h)
	cd riscv-isa-sim && mkdir -p build && cd build && ../configure --prefix=$(riscv_dir) --target=riscv64-unknown-elf --without-boost --without-boost-asio --without-boost-regex
	$(MAKE) -s -C riscv-isa-sim/build libfesvr.a
	$(MAKE) -s -C riscv-isa-sim/build install-hdrs install-config-hdrs
	mkdir -p $(riscv_dir)/lib
	cp riscv-isa-sim/build/libfesvr.a $(riscv_dir)/lib/
	rm -rf riscv-isa-sim/build/

# ESSENT
TestHarness.h:
	java $(JVM_FLAGS) -cp $(ESSENT_JAR) essent.Driver $(FIR_PATH) -O3 --essent-log-level info > essent.log 2>&1

emulator_essent: emulator_essent.cc TestHarness.h riscv/lib/libfesvr.a
	$(CXX) $(CXXFLAGS) $(ESSENT_INCLUDES) emulator_essent.cc -o emulator_essent $(LIBS)

emulator_essent_activity_dump: emulator_essent_dump_activity.cc TestHarness.h riscv/lib/libfesvr.a
	$(CXX) $(CXXFLAGS) $(ESSENT_INCLUDES) emulator_essent_dump_activity.cc -o emulator_essent_activity_dump $(LIBS)

# emulator_essent_prof: emulator_essent.cc TestHarness.h riscv/lib/libfesvr.a
# 	if [ $(NTHREADS) != 1 ] ; then \
# 		$(CXX) $(CXXFLAGS) $(ESSENT_INCLUDES) emulator_essent_prof.cc -o emulator_essent_prof $(LIBS) ; \
# 	fi;
# 	touch $@




.PHONY: all clean clean_emulator_essent emulator_essent_all

emulator_essent_all: emulator_essent emulator_essent_activity_dump

all: emulator_essent_all


clean_emulator_essent:
	rm ./emulator_essent
	rm ./emulator_essent_activity_dump
	rm ./TestHarness.h


clean: clean_emulator_essent

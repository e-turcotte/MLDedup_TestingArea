
CXX := g++
LINK := g++
AR := ar


MAKE_VARIABLES = CXX=$(CXX) LINK=$(LINK) AR=$(AR)


DESIGNS = \
	rocket21-8c \
	rocket21-4c \


SIMS = \
	essent-master \
	essent-dedup \



PREPARE_TARGETS = $(addprefix prepare_,$(SIMS))

${PREPARE_TARGETS}: prepare_%:
	$(MAKE) -C ./$* $(MAKE_VARIABLES) prepare




SIMULATOR_TARGETS = $(addprefix sim_,$(SIMS))

${SIMULATOR_TARGETS}: sim_%:
	$(MAKE) -C ./$* $(MAKE_VARIABLES) emulator_essent



simulator_all: $(SIMULATOR_TARGETS)

prepare: $(PREPARE_TARGETS)




simulator_essent_rocket21-1c:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_rocket21-1c

simulator_essent_rocket21-2c:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_rocket21-2c

simulator_essent_rocket21-4c:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_rocket21-4c

simulator_essent_rocket21-6c:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_rocket21-6c

simulator_essent_rocket21-8c:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_rocket21-8c

simulator_essent_boom21-small:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-small

simulator_essent_boom21-large:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-large

simulator_essent_boom21-mega:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-mega

simulator_essent_boom21-2small:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-2small

simulator_essent_boom21-2large:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-2large

simulator_essent_boom21-2mega:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-2mega

simulator_essent_boom21-4small:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-4small

simulator_essent_boom21-4large:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-4large

simulator_essent_boom21-4mega:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-4mega

simulator_essent_boom21-6small:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-6small

simulator_essent_boom21-6large:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-6large

simulator_essent_boom21-6mega:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-6mega

simulator_essent_boom21-8small:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-8small

simulator_essent_boom21-8large:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-8large

simulator_essent_boom21-8mega:
	$(MAKE) -C essent-master $(MAKE_VARIABLES) compile_essent_boom21-8mega

simulator_dedup_rocket21-1c:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_rocket21-1c

simulator_dedup_rocket21-2c:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_rocket21-2c

simulator_dedup_rocket21-4c:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_rocket21-4c

simulator_dedup_rocket21-6c:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_rocket21-6c

simulator_dedup_rocket21-8c:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_rocket21-8c

simulator_dedup_boom21-small:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-small

simulator_dedup_boom21-large:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-large

simulator_dedup_boom21-mega:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-mega

simulator_dedup_boom21-2small:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-2small

simulator_dedup_boom21-2large:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-2large

simulator_dedup_boom21-2mega:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-2mega

simulator_dedup_boom21-4small:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-4small

simulator_dedup_boom21-4large:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-4large

simulator_dedup_boom21-4mega:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-4mega

simulator_dedup_boom21-6small:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-6small

simulator_dedup_boom21-6large:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-6large

simulator_dedup_boom21-6mega:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-6mega

simulator_dedup_boom21-8small:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-8small

simulator_dedup_boom21-8large:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-8large

simulator_dedup_boom21-8mega:
	$(MAKE) -C essent-dedup $(MAKE_VARIABLES) compile_essent_boom21-8mega

simulator_rocket21-1c: simulator_essent_rocket21-1c simulator_dedup_rocket21-1c

simulator_rocket21-2c: simulator_essent_rocket21-2c simulator_dedup_rocket21-2c

simulator_rocket21-4c: simulator_essent_rocket21-4c simulator_dedup_rocket21-4c

simulator_rocket21-6c: simulator_essent_rocket21-6c simulator_dedup_rocket21-6c

simulator_rocket21-8c: simulator_essent_rocket21-8c simulator_dedup_rocket21-8c

simulator_boom21-small: simulator_essent_boom21-small simulator_dedup_boom21-small

simulator_boom21-large: simulator_essent_boom21-large simulator_dedup_boom21-large

simulator_boom21-mega: simulator_essent_boom21-mega simulator_dedup_boom21-mega

simulator_boom21-2small: simulator_essent_boom21-2small simulator_dedup_boom21-2small

simulator_boom21-2large: simulator_essent_boom21-2large simulator_dedup_boom21-2large

simulator_boom21-2mega: simulator_essent_boom21-2mega simulator_dedup_boom21-2mega

simulator_boom21-4small: simulator_essent_boom21-4small simulator_dedup_boom21-4small

simulator_boom21-4large: simulator_essent_boom21-4large simulator_dedup_boom21-4large

simulator_boom21-4mega: simulator_essent_boom21-4mega simulator_dedup_boom21-4mega

simulator_boom21-6small: simulator_essent_boom21-6small simulator_dedup_boom21-6small

simulator_boom21-6large: simulator_essent_boom21-6large simulator_dedup_boom21-6large

simulator_boom21-6mega: simulator_essent_boom21-6mega simulator_dedup_boom21-6mega

simulator_boom21-8small: simulator_essent_boom21-8small simulator_dedup_boom21-8small

simulator_boom21-8large: simulator_essent_boom21-8large simulator_dedup_boom21-8large

simulator_boom21-8mega: simulator_essent_boom21-8mega simulator_dedup_boom21-8mega


EXTRA_PHOTY = simulator_essent_rocket21-1c simulator_essent_rocket21-2c simulator_essent_rocket21-4c simulator_essent_rocket21-6c simulator_essent_rocket21-8c simulator_essent_boom21-small simulator_essent_boom21-large simulator_essent_boom21-mega simulator_essent_boom21-2small simulator_essent_boom21-2large simulator_essent_boom21-2mega simulator_essent_boom21-4small simulator_essent_boom21-4large simulator_essent_boom21-4mega simulator_essent_boom21-6small simulator_essent_boom21-6large simulator_essent_boom21-6mega simulator_essent_boom21-8small simulator_essent_boom21-8large simulator_essent_boom21-8mega simulator_dedup_rocket21-1c simulator_dedup_rocket21-2c simulator_dedup_rocket21-4c simulator_dedup_rocket21-6c simulator_dedup_rocket21-8c simulator_dedup_boom21-small simulator_dedup_boom21-large simulator_dedup_boom21-mega simulator_dedup_boom21-2small simulator_dedup_boom21-2large simulator_dedup_boom21-2mega simulator_dedup_boom21-4small simulator_dedup_boom21-4large simulator_dedup_boom21-4mega simulator_dedup_boom21-6small simulator_dedup_boom21-6large simulator_dedup_boom21-6mega simulator_dedup_boom21-8small simulator_dedup_boom21-8large simulator_dedup_boom21-8mega simulator_po_rocket21-1c simulator_po_rocket21-2c simulator_po_rocket21-4c simulator_po_rocket21-6c simulator_po_rocket21-8c simulator_po_boom21-small simulator_po_boom21-large simulator_po_boom21-mega simulator_po_boom21-2small simulator_po_boom21-2large simulator_po_boom21-2mega simulator_po_boom21-4small simulator_po_boom21-4large simulator_po_boom21-4mega simulator_po_boom21-6small simulator_po_boom21-6large simulator_po_boom21-6mega simulator_po_boom21-8small simulator_po_boom21-8large simulator_po_boom21-8mega simulator_dedup-nolocality_rocket21-1c simulator_dedup-nolocality_rocket21-2c simulator_dedup-nolocality_rocket21-4c simulator_dedup-nolocality_rocket21-6c simulator_dedup-nolocality_rocket21-8c simulator_dedup-nolocality_boom21-small simulator_dedup-nolocality_boom21-large simulator_dedup-nolocality_boom21-mega simulator_dedup-nolocality_boom21-2small simulator_dedup-nolocality_boom21-2large simulator_dedup-nolocality_boom21-2mega simulator_dedup-nolocality_boom21-4small simulator_dedup-nolocality_boom21-4large simulator_dedup-nolocality_boom21-4mega simulator_dedup-nolocality_boom21-6small simulator_dedup-nolocality_boom21-6large simulator_dedup-nolocality_boom21-6mega simulator_dedup-nolocality_boom21-8small simulator_dedup-nolocality_boom21-8large simulator_dedup-nolocality_boom21-8mega simulator_rocket21-1c simulator_rocket21-2c simulator_rocket21-4c simulator_rocket21-6c simulator_rocket21-8c simulator_boom21-small simulator_boom21-large simulator_boom21-mega simulator_boom21-2small simulator_boom21-2large simulator_boom21-2mega simulator_boom21-4small simulator_boom21-4large simulator_boom21-4mega simulator_boom21-6small simulator_boom21-6large simulator_boom21-6mega simulator_boom21-8small simulator_boom21-8large simulator_boom21-8mega



.PHONY: simulator $(SIMULATOR_TARGETS) prepare $(PREPARE_TARGETS) $(SIMULATOR_ALL_TARGETS) $(EXTRA_PHOTY)


CXX := g++
LINK := g++
AR := ar


MAKE_VARIABLES = CXX=$(CXX) LINK=$(LINK) AR=$(AR)


# Designs to compile
DESIGNS = \
	rocket21-1c \
	rocket21-2c \
	rocket21-4c \
	rocket21-6c \
	rocket21-8c \
	boom21-small \
	boom21-2small \
	boom21-4small \
	boom21-6small \
	boom21-8small \
	boom21-large \
	boom21-2large \
	boom21-4large \
	boom21-6large \
	boom21-8large \
	boom21-mega \
	boom21-2mega \
	boom21-4mega \
	boom21-6mega \
	boom21-8mega \


SIMS = \
	essent-master \
	essent-dedup \
	essent-mldedup \



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

simulator_mldedup_rocket21-1c:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_rocket21-1c

simulator_mldedup_rocket21-2c:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_rocket21-2c

simulator_mldedup_rocket21-4c:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_rocket21-4c

simulator_mldedup_rocket21-6c:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_rocket21-6c

simulator_mldedup_rocket21-8c:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_rocket21-8c

simulator_mldedup_boom21-small:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-small

simulator_mldedup_boom21-large:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-large

simulator_mldedup_boom21-mega:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-mega

simulator_mldedup_boom21-2small:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-2small

simulator_mldedup_boom21-2large:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-2large

simulator_mldedup_boom21-2mega:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-2mega

simulator_mldedup_boom21-4small:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-4small

simulator_mldedup_boom21-4large:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-4large

simulator_mldedup_boom21-4mega:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-4mega

simulator_mldedup_boom21-6small:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-6small

simulator_mldedup_boom21-6large:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-6large

simulator_mldedup_boom21-6mega:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-6mega

simulator_mldedup_boom21-8small:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-8small

simulator_mldedup_boom21-8large:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-8large

simulator_mldedup_boom21-8mega:
	$(MAKE) -C essent-mldedup $(MAKE_VARIABLES) compile_essent_boom21-8mega

simulator_rocket21-1c: simulator_essent_rocket21-1c simulator_dedup_rocket21-1c simulator_mldedup_rocket21-1c

simulator_rocket21-2c: simulator_essent_rocket21-2c simulator_dedup_rocket21-2c simulator_mldedup_rocket21-2c

simulator_rocket21-4c: simulator_essent_rocket21-4c simulator_dedup_rocket21-4c simulator_mldedup_rocket21-4c

simulator_rocket21-6c: simulator_essent_rocket21-6c simulator_dedup_rocket21-6c simulator_mldedup_rocket21-6c

simulator_rocket21-8c: simulator_essent_rocket21-8c simulator_dedup_rocket21-8c simulator_mldedup_rocket21-8c

simulator_boom21-small: simulator_essent_boom21-small simulator_dedup_boom21-small simulator_mldedup_boom21-small

simulator_boom21-large: simulator_essent_boom21-large simulator_dedup_boom21-large simulator_mldedup_boom21-large

simulator_boom21-mega: simulator_essent_boom21-mega simulator_dedup_boom21-mega simulator_mldedup_boom21-mega

simulator_boom21-2small: simulator_essent_boom21-2small simulator_dedup_boom21-2small simulator_mldedup_boom21-2small

simulator_boom21-2large: simulator_essent_boom21-2large simulator_dedup_boom21-2large simulator_mldedup_boom21-2large

simulator_boom21-2mega: simulator_essent_boom21-2mega simulator_dedup_boom21-2mega simulator_mldedup_boom21-2mega

simulator_boom21-4small: simulator_essent_boom21-4small simulator_dedup_boom21-4small simulator_mldedup_boom21-4small

simulator_boom21-4large: simulator_essent_boom21-4large simulator_dedup_boom21-4large simulator_mldedup_boom21-4large

simulator_boom21-4mega: simulator_essent_boom21-4mega simulator_dedup_boom21-4mega simulator_mldedup_boom21-4mega

simulator_boom21-6small: simulator_essent_boom21-6small simulator_dedup_boom21-6small simulator_mldedup_boom21-6small

simulator_boom21-6large: simulator_essent_boom21-6large simulator_dedup_boom21-6large simulator_mldedup_boom21-6large

simulator_boom21-6mega: simulator_essent_boom21-6mega simulator_dedup_boom21-6mega simulator_mldedup_boom21-6mega

simulator_boom21-8small: simulator_essent_boom21-8small simulator_dedup_boom21-8small simulator_mldedup_boom21-8small

simulator_boom21-8large: simulator_essent_boom21-8large simulator_dedup_boom21-8large simulator_mldedup_boom21-8large

simulator_boom21-8mega: simulator_essent_boom21-8mega simulator_dedup_boom21-8mega simulator_mldedup_boom21-8mega


EXTRA_PHOTY = simulator_essent_rocket21-1c simulator_essent_rocket21-2c simulator_essent_rocket21-4c simulator_essent_rocket21-6c simulator_essent_rocket21-8c simulator_essent_boom21-small simulator_essent_boom21-large simulator_essent_boom21-mega simulator_essent_boom21-2small simulator_essent_boom21-2large simulator_essent_boom21-2mega simulator_essent_boom21-4small simulator_essent_boom21-4large simulator_essent_boom21-4mega simulator_essent_boom21-6small simulator_essent_boom21-6large simulator_essent_boom21-6mega simulator_essent_boom21-8small simulator_essent_boom21-8large simulator_essent_boom21-8mega simulator_dedup_rocket21-1c simulator_dedup_rocket21-2c simulator_dedup_rocket21-4c simulator_dedup_rocket21-6c simulator_dedup_rocket21-8c simulator_dedup_boom21-small simulator_dedup_boom21-large simulator_dedup_boom21-mega simulator_dedup_boom21-2small simulator_dedup_boom21-2large simulator_dedup_boom21-2mega simulator_dedup_boom21-4small simulator_dedup_boom21-4large simulator_dedup_boom21-4mega simulator_dedup_boom21-6small simulator_dedup_boom21-6large simulator_dedup_boom21-6mega simulator_dedup_boom21-8small simulator_dedup_boom21-8large simulator_dedup_boom21-8mega simulator_mldedup_rocket21-1c simulator_mldedup_rocket21-2c simulator_mldedup_rocket21-4c simulator_mldedup_rocket21-6c simulator_mldedup_rocket21-8c simulator_mldedup_boom21-small simulator_mldedup_boom21-large simulator_mldedup_boom21-mega simulator_mldedup_boom21-2small simulator_mldedup_boom21-2large simulator_mldedup_boom21-2mega simulator_mldedup_boom21-4small simulator_mldedup_boom21-4large simulator_mldedup_boom21-4mega simulator_mldedup_boom21-6small simulator_mldedup_boom21-6large simulator_mldedup_boom21-6mega simulator_mldedup_boom21-8small simulator_mldedup_boom21-8large simulator_mldedup_boom21-8mega simulator_rocket21-1c simulator_rocket21-2c simulator_rocket21-4c simulator_rocket21-6c simulator_rocket21-8c simulator_boom21-small simulator_boom21-large simulator_boom21-mega simulator_boom21-2small simulator_boom21-2large simulator_boom21-2mega simulator_boom21-4small simulator_boom21-4large simulator_boom21-4mega simulator_boom21-6small simulator_boom21-6large simulator_boom21-6mega simulator_boom21-8small simulator_boom21-8large simulator_boom21-8mega



.PHONY: simulator $(SIMULATOR_TARGETS) prepare $(PREPARE_TARGETS) $(SIMULATOR_ALL_TARGETS) $(EXTRA_PHOTY)

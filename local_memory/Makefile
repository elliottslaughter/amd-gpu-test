HIPCC ?= hipcc
LLVM_AS ?= llvm-as
LLVM_DIS ?= llvm-dis
CLANG_OFFLOAD_BUNDLER ?= clang-offload-bundler

HIPCCFLAGS ?=
HIPCCFLAGS += -fgpu-rdc -Wall
LDFLAGS ?=

.PHONY: all
all: histogram_hip histogram_terra

test_terra_host.o: test_terra.t
	../legion/language/regent.py -g test_terra.t

%.o:%.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -c $<

%.bc:%.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -c -emit-llvm $<

histogram_hip.o:histogram.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -c $<
histogram_terra.o:histogram.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -DTERRA_HACK -c $<

histogram_hip: test_hip.o histogram_hip.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) $^ $(LDFLAGS)

histogram_terra: test_terra_host.o histogram_terra.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) $^ $(LDFLAGS)

.PHONY: debug
debug: test_hip.bc
	$(CLANG_OFFLOAD_BUNDLER) --unbundle --inputs=test_hip.bc --type=o --outputs=test_hip.unbundle_device.bc --targets=hip-amdgcn-amd-amdhsa-$(TERRA_AMDGPU_TARGET)
	$(CLANG_OFFLOAD_BUNDLER) --unbundle --inputs=test_hip.bc --type=o --outputs=test_hip.unbundle_host.bc --targets=host-x86_64-unknown-linux-gnu
	$(LLVM_DIS) test_hip.unbundle_device.bc
	$(LLVM_DIS) test_hip.unbundle_host.bc

.PHONY: clean
clean:
	rm -f *.o *.ll *.bc histogram_hip histogram_terra

HIPCC ?= hipcc
LLVM_AS ?= llvm-as
LLVM_DIS ?= llvm-dis
CLANG_OFFLOAD_BUNDLER ?= clang-offload-bundler

HIPCCFLAGS ?=
HIPCCFLAGS += -fgpu-rdc -Wall
LDFLAGS ?=

.PHONY: all
all: saxpy_hip saxpy_terra

test_terra.o: test_terra.t
	../legion/language/regent.py test_terra.t
	$(LLVM_AS) test_terra_device.ll
	$(CLANG_OFFLOAD_BUNDLER) --inputs=test_terra_host.o,test_terra_device.bc --type=o --outputs=test_terra.o --targets=host-x86_64-unknown-linux-gnu,hip-amdgcn-amd-amdhsa-gfx90a

%.o:%.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -c $<

%.bc:%.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -c -emit-llvm $<

saxpy_hip.o:saxpy.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -c $<
saxpy_terra.o:saxpy.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -DTERRA_HACK -c $<

saxpy_hip: test_hip.o saxpy_hip.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) $^ $(LDFLAGS)

saxpy_terra: test_terra.o saxpy_terra.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) $^ $(LDFLAGS)

.PHONY: debug
debug: test_hip.bc
	$(CLANG_OFFLOAD_BUNDLER) --unbundle --inputs=test_hip.bc --type=o --outputs=test_hip.unbundle_device.bc --targets=hip-amdgcn-amd-amdhsa-$(TERRA_AMDGPU_TARGET)
	$(CLANG_OFFLOAD_BUNDLER) --unbundle --inputs=test_hip.bc --type=o --outputs=test_hip.unbundle_host.bc --targets=host-x86_64-unknown-linux-gnu
	$(LLVM_DIS) test_hip.unbundle_device.bc
	$(LLVM_DIS) test_hip.unbundle_host.bc

.PHONY: clean
clean:
	rm -f *.o *.ll *.bc saxpy_hip saxpy_terra

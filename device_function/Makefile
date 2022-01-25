HIPCC ?= hipcc
LLVM_AS ?= llvm-as
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

saxpy_hip: test_hip.o saxpy.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) $^ $(LDFLAGS)

saxpy_terra: test_terra.o saxpy.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) $^ $(LDFLAGS)

.PHONY: clean
clean:
	rm -f *.o *.ll *.bc saxpy_hip saxpy_terra

HIPCC ?= hipcc

HIPCCFLAGS ?=
HIPCCFLAGS += -fgpu-rdc -Wall
LDFLAGS ?=

.PHONY: all
all: saxpy_hip saxpy_terra

test_terra.o: target.t
	legion/language/regent.py target.t
	llvm-as test_terra_host.ll
	llvm-as test_terra_device.ll
	clang-offload-bundler --inputs=test_terra_host.bc --inputs=test_terra_device.bc --type=o --outputs=test_terra.o --targets=host-x86_64-unknown-linux-gnu --targets=hip-amdgcn-amd-amdhsa-gfx908

%.o:%.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -c $<

saxpy_hip: test_hip.o saxpy.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) $^ $(LDFLAGS)

saxpy_terra: test_terra.o saxpy.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) $^ $(LDFLAGS)

.PHONY: clean
clean:
	rm -f *.o *.ll *.bc saxpy_hip saxpy_terra

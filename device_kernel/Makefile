HIPCC ?= hipcc

HIPCCFLAGS ?=
HIPCCFLAGS += -fgpu-rdc -Wall
LDFLAGS ?=

.PHONY: all
all: saxpy_hip saxpy_terra

test_terra.o: test_terra.t
	../legion/language/regent.py test_terra.t
	llvm-as test_terra_device.ll
	clang-offload-bundler --inputs=test_terra_host.o,test_terra_device.bc --type=o --outputs=test_terra.o --targets=host-x86_64-unknown-linux-gnu,hip-amdgcn-amd-amdhsa-gfx908

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
	clang-offload-bundler --unbundle --inputs=test_hip.bc --type=o --outputs=test_hip.unbundle_device.bc --targets=hip-amdgcn-amd-amdhsa-gfx908
	clang-offload-bundler --unbundle --inputs=test_hip.bc --type=o --outputs=test_hip.unbundle_host.bc --targets=host-x86_64-unknown-linux-gnu
	llvm-dis test_hip.unbundle_device.bc
	llvm-dis test_hip.unbundle_host.bc

.PHONY: clean
clean:
	rm -f *.o *.ll *.bc saxpy_hip saxpy_terra

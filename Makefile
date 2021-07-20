HIPCC ?= hipcc

HIPCCFLAGS ?=
HIPCCFLAGS += -fgpu-rdc -Wall
LDFLAGS ?=

.PHONY: all
all: saxpy_hip saxpy_terra

test_terra.o: target.t
	legion/language/regent.py target.t

%.o:%.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -c $<

saxpy_hip: test_hip.o saxpy.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) $^ $(LDFLAGS)

saxpy_terra: test_terra.o saxpy.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) $^ $(LDFLAGS)

.PHONY: clean
clean:
	rm -f *.o saxpy_hip saxpy_terra

HIPCC ?= hipcc

HIPCCFLAGS ?=
HIPCCFLAGS += -fgpu-rdc -Wall
LDFLAGS ?=

BIN := saxpy

.PHONY: all
all:  $(BIN)

test.o: target.t
	legion/language/regent.py target.t

%.o:%.cc
	$(HIPCC) -o $@ $(HIPCCFLAGS) -c $<

$(BIN): %:%.o test.o test_hip.o
	$(HIPCC) -o $@ $(HIPCCFLAGS) test_hip.o $< $(LDFLAGS)

.PHONY: clean
clean:
	rm -f *.o $(BIN)

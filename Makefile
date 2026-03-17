# Build target for the current repo layout
# - GPU binary: GPUMain.cu + GPUMD5.cu

# Toolchain
NVCC    ?= nvcc

# Output naming (Windows uses .exe)
EXE :=
ifeq ($(OS),Windows_NT)
EXE := .exe
endif

# Flags
NVCCFLAGS   ?= -O2
LDFLAGS     ?=
LDLIBS      ?=

# Binaries
GPU_BIN := project$(EXE)

.PHONY: all gpu clean

all: gpu

gpu: $(GPU_BIN)

$(GPU_BIN): GPUMain.cu GPUMD5.cu GPUMD5.h
	$(NVCC) $(NVCCFLAGS) -o $@ GPUMain.cu GPUMD5.cu -lcrypto

clean:
ifeq ($(OS),Windows_NT)
	-@del /Q $(GPU_BIN) 2>NUL
else
	$(RM) -f $(GPU_BIN)
endif

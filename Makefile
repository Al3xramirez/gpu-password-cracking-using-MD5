# Build targets for the current repo layout
# - CPU binary: CpuMD5.c
# - GPU binary: GPUMain.cu + GPUMD5.cu

# Toolchain
CC      ?= gcc
NVCC    ?= nvcc

# Output naming (Windows uses .exe)
EXE :=
ifeq ($(OS),Windows_NT)
EXE := .exe
endif

# Flags
CFLAGS      ?= -O2 -Wall -Wextra
NVCCFLAGS   ?= -O2
LDFLAGS     ?=
LDLIBS      ?=

# Binaries
CPU_BIN := cpu_md5$(EXE)
GPU_BIN := gpu_md5$(EXE)

.PHONY: all cpu gpu clean

all: cpu gpu

cpu: $(CPU_BIN)

gpu: $(GPU_BIN)

$(CPU_BIN): CpuMD5.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) $(LDLIBS) -lcrypto

$(GPU_BIN): GPUMain.cu GPUMD5.cu GPUMD5.h
	$(NVCC) $(NVCCFLAGS) -o $@ GPUMain.cu GPUMD5.cu

clean:
ifeq ($(OS),Windows_NT)
	-@del /Q $(CPU_BIN) $(GPU_BIN) 2>NUL
else
	$(RM) -f $(CPU_BIN) $(GPU_BIN)
endif

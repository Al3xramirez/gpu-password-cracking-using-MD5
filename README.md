# Password Cracking Using MD5 with Multiple GPU Devices

## Overview
This project implements a GPU-accelerated password cracking system using the MD5 hashing algorithm. The system demonstrates how parallel processing across multiple GPU devices can dramatically reduce the time required to brute-force crack a password hash.

MD5 is no longer considered secure for modern cryptographic applications due to its vulnerabilities. However, its computational simplicity makes it ideal for demonstrating high-performance parallel computing techniques using CUDA.

The project compares performance across three implementations:

- CPU-based brute-force cracking
- Single GPU CUDA implementation
- Multi-GPU CUDA implementation

The goal is to evaluate the performance improvements gained through GPU parallelization and multi-device workload distribution. This is also our final project for CSCD445 GPU Computing.

---

## Project Objectives

The objectives of this project are:

1. Implement a brute-force password cracking system using the MD5 algorithm.
2. Utilize GPU parallelization to accelerate password hash computation.
3. Distribute work across multiple GPUs to further improve performance.
4. Compare runtime performance between CPU, single GPU, and multi-GPU implementations.

---

## System Architecture

The system consists of three main components.

### CPU Brute-Force Implementation
The CPU implementation generates password candidates sequentially and computes their MD5 hashes until the target hash is found.

Characteristics:

- Sequential execution
- Baseline for performance comparison
- Lower throughput compared to GPU

---

### Single GPU Implementation

A CUDA kernel is used to parallelize password testing across thousands of threads.

Each GPU thread performs the following steps:

1. Generates a unique password candidate
2. Computes the MD5 hash
3. Compares the computed hash with the target hash
4. Signals success if a match is found

#### CUDA Kernel Design

- Each thread tests a different password candidate
- MD5 computation is performed directly on the GPU
- Atomic operations are used to signal when a password is found
- Threads terminate early once the correct password is discovered

---

### Multi-GPU Implementation

The multi-GPU version distributes the search space across multiple GPU devices.

Steps:

1. Detect available GPU devices using `cudaGetDeviceCount()`
2. Divide the password search space among GPUs
3. Launch separate kernels on each GPU
4. Coordinate execution from the CPU

The CPU acts as a controller that:

- Assigns work ranges to each GPU
- Launches kernels on each device
- Synchronizes execution
- Collects results

---

## Password Search Space

Passwords are generated using the following constraints:

- Character set: `a–z`, `A–Z`
- Maximum password length: **8 characters**
- Brute-force search of all possible combinations

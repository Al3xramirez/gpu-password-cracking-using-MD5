# Password Cracking Using MD5 with GPU Acceleration

## Overview
This project implements a password cracking system using the MD5 hashing algorithm, with both a CPU-based and a GPU-based solution. The purpose of the project is to demonstrate how GPU parallelism can significantly accelerate brute-force password cracking compared to traditional CPU execution.

Although MD5 is no longer considered secure for modern cryptographic applications because of its known vulnerabilities, it is still a useful algorithm for demonstrating parallel computing concepts. Its relatively simple structure makes it well suited for comparing sequential execution on a CPU with massively parallel execution on a GPU using CUDA.

This project compares performance across two implementations:

- CPU-based brute-force cracking
- Single GPU CUDA implementation

The goal is to evaluate the performance improvement gained by using GPU parallelization for password hash computation. This project was completed as our final project for **CSCD 445 GPU Computing**.

---

## Project Objectives

The objectives of this project are:

1. Implement a brute-force password cracking system using the MD5 algorithm.
2. Develop a CPU version as a baseline for performance comparison.
3. Develop a GPU version using CUDA to accelerate password testing.
4. Compare runtime performance between CPU and GPU implementations.

---

## System Architecture

All experiments for this project were executed on a system equipped with the following hardware.

### CPU
- **Processor:** AMD Ryzen 7 HX Series
- **Role:**  
  - Executes the CPU brute-force password cracking implementation  
  - Acts as the **host controller** for the GPU implementation  
  - Launches CUDA kernels and manages memory transfers between host and device

### GPU
- **GPU Model:** NVIDIA GeForce RTX 5060 Laptop GPU  
- **Driver Version:** 591.59  
- **CUDA Version:** 13.1  
- **Total GPU Memory:** 8 GB (8151 MiB)  
- **GPU Memory in Use During Execution:** ~413 MiB  

### CPU Brute-Force Implementation

The CPU implementation generates password candidates sequentially and computes their MD5 hashes one at a time until the target hash is found. For this CPU Implementation, the offical MD5 implementation (RFC 1321).

**Characteristics:**

- Sequential execution
- Serves as the performance baseline
- Lower throughput compared to GPU execution
- Uses the official MD5 API/library rather than implementing MD5 entirely from scratch

This version demonstrates the limitations of a traditional brute-force approach when compared to parallel execution on a GPU.

---

### Single GPU Implementation

The GPU implementation uses CUDA to parallelize password testing across many threads. Instead of testing one password candidate at a time like the CPU, the GPU allows thousands of candidates to be tested simultaneously. For the MD5 implementation, we used that same offical MD5 implementation with some modifications within the kernel.

Each GPU thread performs the following steps:

1. Generate a unique password candidate
2. Compute the MD5 hash
3. Compare the computed hash with the target hash
4. Signal success if a match is found

#### CUDA Kernel Design

- Each stride computed thousands of password candidates for each thread. Instead of the regular thread assigning to one index.
- MD5 computation is performed directly on the GPU
- Parallel execution greatly increases search throughput
- Once a matching password is found, the result is stored and returned to the host

This design allows the GPU to process a much larger number of password candidates in the same amount of time compared to the CPU version.

---

## Password Search Space

Passwords are generated using the following constraints:

- Character set: `a–z`, `A–Z`
- Maximum password length: **8 characters**
- Brute-force search of possible combinations within the defined search range
- 53 trillion possible combinations
- Due to time restraints, we could not test passwords that would take up to the trillions, so we tested passwords up to the 1 trillionth index.

Each candidate password is mapped from an index value, allowing the program to systematically test combinations in order.

---

## Performance Comparison

The CPU and GPU implementations are both designed to solve the same problem: finding the original password corresponding to a target MD5 hash. However, the methods used are very different.

### CPU
- Processes password candidates one at a time
- Simpler control flow
- Much slower for large search spaces

### GPU
- Processes many password candidates in parallel
- Better suited for brute-force search problems
- Much faster than the CPU version for large workloads

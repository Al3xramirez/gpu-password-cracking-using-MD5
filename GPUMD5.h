#ifndef GPUMD5_H
#define GPUMD5_H

#include <stdint.h>
#include <cuda_runtime.h>

#define BLOCK_SIZE 256
#define PASSWORD_LENGTH 8
#define MD5_DIGEST_LENGTH 16

// Checks indices in the half-open interval: [start_index, end_index)
__global__ void compute_md5(unsigned char *hashed_string, char *correct_password, uint64_t start_index, uint64_t end_index, int *found, uint64_t *found_index);

#endif
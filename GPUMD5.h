#ifndef GPUMD5_H
#define GPUMD5_H

#include <stdint.h>
#include <cuda_runtime.h>

#define BLOCK_SIZE 256
#define PASSWORD_LENGTH 8
#define MD5_DIGEST_LENGTH 16

__global__ void compute_md5(unsigned char *hashed_string, char *correct_password);

#endif
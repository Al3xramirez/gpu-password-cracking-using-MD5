#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <cuda_runtime.h>
#include <time.h>
#include "GPUMD5.h"

int main() {
    // Target hash:
    // Password: bXirrMvB
    // MD5: 0cf7a2bb526670cfd4ac53b7ee627eec
    // 2 Trillion
   /* unsigned char h_input[16] = {
        0x0c, 0xf7, 0xa2, 0xbb,
        0x52, 0x66, 0x70, 0xcf,
        0xd4, 0xac, 0x53, 0xb7,
        0xee, 0x62, 0x7e, 0xec
    };*/
    
    // Target hash:
    // Password: ZZZZZZZZ
    // MD5: 59ec5c1e0e06e6e9e18c44ee8ed035e5
    // Last password in full 52^8 space
   /* unsigned char h_input[16] = {
        0x59, 0xec, 0x5c, 0x1e,
        0x0e, 0x06, 0xe6, 0xe9,
        0xe1, 0x8c, 0x44, 0xee,
        0x8e, 0xd0, 0x35, 0xe5
    };*/

    // Target hash:
    // Password: WHarBysy
    // MD5: 58c34f703a0720c5cd334c11d1bec6da
    // Index: 50,000,000,000,000 (0-based)
    unsigned char h_input[16] = {
        0x58, 0xc3, 0x4f, 0x70,
        0x3a, 0x07, 0x20, 0xc5,
        0xcd, 0x33, 0x4c, 0x11,
        0xd1, 0xbe, 0xc6, 0xda
    };


    char *h_output = (char *)malloc(PASSWORD_LENGTH + 1);
    if (h_output == NULL) {
        printf("Host memory allocation failed.\n");
        return 1;
    }
    memset(h_output, 0, PASSWORD_LENGTH + 1);

    unsigned char *d_input;
    char *d_output;

    int *d_found;
    int h_found = 0;

    cudaMalloc((void **)&d_found, sizeof(int));
    cudaMalloc((void **)&d_input, MD5_DIGEST_LENGTH);
    cudaMalloc((void **)&d_output, PASSWORD_LENGTH + 1);

    cudaMemcpy(d_found, &h_found, sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_input, h_input, MD5_DIGEST_LENGTH, cudaMemcpyHostToDevice);
    cudaMemset(d_output, 0, PASSWORD_LENGTH + 1);

    uint64_t max_index = 53459728531456ULL;; 

    time_t start, end;
    time(&start);

    compute_md5<<<65535, 256>>>(d_input, d_output, max_index, d_found);

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        printf("Kernel launch error: %s\n", cudaGetErrorString(err));
    }

    cudaError_t syncErr = cudaDeviceSynchronize();
    if (syncErr != cudaSuccess) {
        printf("Kernel runtime error: %s\n", cudaGetErrorString(syncErr));
    }

    cudaMemcpy(&h_found, d_found, sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_output, d_output, PASSWORD_LENGTH + 1, cudaMemcpyDeviceToHost);

    time(&end);
    double time_taken = difftime(end, start);

    printf("Found flag: %d\n", h_found);
    printf("Returned password: %s\n", h_output);
    printf("Time taken: %f seconds\n", time_taken);

    cudaFree(d_input);
    cudaFree(d_output);
    cudaFree(d_found);
    free(h_output);

    return 0;
}
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <cuda_runtime.h>
#include <time.h>
#include "GPUMD5.h"

int main() {
    // Target hash:
    // Password: bXirrMvB
    // MD5: 0cf7a2bb526670cfd4ac53b7ee627eec
    // 2 Trillion 
    unsigned char h_input[16] = {
        0x0c, 0xf7, 0xa2, 0xbb,
        0x52, 0x66, 0x70, 0xcf,
        0xd4, 0xac, 0x53, 0xb7,
        0xee, 0x62, 0x7e, 0xec
    };

    char *h_output = (char *)malloc(PASSWORD_LENGTH + 1);
    if (h_output == NULL) {
        printf("Host memory allocation failed.\n");
        return 1;
    }

    unsigned char *d_input;
    char *d_output;

    cudaMalloc((void **)&d_input, MD5_DIGEST_LENGTH);
    cudaMalloc((void **)&d_output, PASSWORD_LENGTH + 1);

    cudaMemcpy(d_input, h_input, MD5_DIGEST_LENGTH, cudaMemcpyHostToDevice);

    time_t start, end;
    time(&start);

    // 2,000,000,000,000 total threads
    // 1,953,125,000 blocks * 1024 threads/block = 2,000,000,000,000
    compute_md5<<<2147483647, 1024>>>(d_input, d_output);

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        printf("Kernel launch error: %s\n", cudaGetErrorString(err));
    }

    cudaDeviceSynchronize();

    cudaMemcpy(h_output, d_output, PASSWORD_LENGTH + 1, cudaMemcpyDeviceToHost);

    time(&end);
    double time_taken = difftime(end, start);

    printf("Returned password: %s\n", h_output);
    printf("Time taken: %f seconds\n", time_taken);

    cudaFree(d_input);
    cudaFree(d_output);
    free(h_output);

    return 0;
}
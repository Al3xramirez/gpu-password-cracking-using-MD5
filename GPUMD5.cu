#include "GPUMD5.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <cuda_runtime.h>

// MD5 functions and constants
#define F(x,y,z) ((x&y) | (~x & z))
#define G(x,y,z) ((x&z) | (y & ~z))
#define H(x,y,z) (x ^ y ^ z)
#define I(x,y,z) (y ^ (x | ~z))
#define LEFTROTATE(x,c) (((x) << (c)) | ((x) >> (32-(c))))

// Character set for password generation (52 characters: a-z and A-Z)
__constant__ char charSet[] =
{'a','b','c','d','e','f','g','h','i','j','k','l','m',
 'n','o','p','q','r','s','t','u','v','w','x','y','z',
 'A','B','C','D','E','F','G','H','I','J','K','L','M',
 'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'};

// Shift amounts for each round
__constant__ uint32_t shift[64] = {
    7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
    5,9,14,20, 5,9,14,20, 5,9,14,20, 5,9,14,20,
    4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
    6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21
};

// T[i] = floor(2^32 * abs(sin(i + 1))) for i = 0 to 63
__constant__ uint32_t T[64] = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
};

/*
    Generate a unique 8-character string from the thread index.
*/
__device__ void generate_string(uint64_t index, char *string) {
    for (int i = PASSWORD_LENGTH - 1; i >= 0; i--) {
        string[i] = charSet[index % 52];
        index /= 52;
    }
    string[PASSWORD_LENGTH] = '\0';
}

/*
    Kernel: each thread generates one password candidate, hashes it with MD5,
    and compares the digest against the target hash.
    hashed_string: target MD5 hash to match
    correct_password: output buffer to store the found password
    max_index: total number of password candidates to check (52^8)
    found: flag to indicate if the password has been found (1 if found, 0 otherwise)
*/
__global__ void compute_md5(unsigned char *hashed_string, char *correct_password, uint64_t max_index, int *found) {

    // Global thread ID
    uint64_t idx = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    uint64_t stride = (uint64_t)gridDim.x * blockDim.x;

    if (*found) return;

    for(uint64_t current_index = idx; current_index < max_index; current_index += stride) {

        if (*found) return;
        // Generate candidate password
        char candidate_string[PASSWORD_LENGTH + 1];
        generate_string(current_index, candidate_string);

        uint32_t word_block[16];

        word_block[0] = ((uint32_t)candidate_string[0]) |
                        ((uint32_t)candidate_string[1] << 8) |
                        ((uint32_t)candidate_string[2] << 16) |
                        ((uint32_t)candidate_string[3] << 24);

        word_block[1] = ((uint32_t)candidate_string[4]) |
                        ((uint32_t)candidate_string[5] << 8) |
                        ((uint32_t)candidate_string[6] << 16) |
                        ((uint32_t)candidate_string[7] << 24);

        word_block[2] = 0x80; //Add the padding bit (1 bit followed by 0 bits)

        for (int i = 3; i < 16; i++) {
            word_block[i] = 0;
        }

        word_block[14] = 64;
        word_block[15] = 0;

        // Step 3: Initialize MD5 buffer
        uint32_t A = 0x67452301;
        uint32_t B = 0xEFCDAB89;
        uint32_t C = 0x98BADCFE;
        uint32_t D = 0x10325476;
        
        uint32_t AA = A;
        uint32_t BB = B;
        uint32_t CC = C;
        uint32_t DD = D;

        // Main MD5 loop
        for (int i = 0; i < 64; i++) {
            uint32_t f;
            int g;

            if (i < 16) {
                f = F(B, C, D);
                g = i;
            } else if (i < 32) {
                f = G(B, C, D);
                g = (5 * i + 1) % 16;
            } else if (i < 48) {
                f = H(B, C, D);
                g = (3 * i + 5) % 16;
            } else {
                f = I(B, C, D);
                g = (7 * i) % 16;
            }

            uint32_t temp = D;
            D = C;
            C = B;
            B = B + LEFTROTATE(A + f + T[i] + word_block[g], shift[i]);
            A = temp;
        }

        // Final additions
        A += AA;
        B += BB;
        C += CC;
        D += DD;

        // Store digest in little-endian format
        unsigned char digest[16];

        digest[0]  = A & 0xFF;
        digest[1]  = (A >> 8) & 0xFF;
        digest[2]  = (A >> 16) & 0xFF;
        digest[3]  = (A >> 24) & 0xFF;

        digest[4]  = B & 0xFF;
        digest[5]  = (B >> 8) & 0xFF;
        digest[6]  = (B >> 16) & 0xFF;
        digest[7]  = (B >> 24) & 0xFF;

        digest[8]  = C & 0xFF;
        digest[9]  = (C >> 8) & 0xFF;
        digest[10] = (C >> 16) & 0xFF;
        digest[11] = (C >> 24) & 0xFF;

        digest[12] = D & 0xFF;
        digest[13] = (D >> 8) & 0xFF;
        digest[14] = (D >> 16) & 0xFF;
        digest[15] = (D >> 24) & 0xFF;

        // Compare computed digest to target hash
        bool match = true;
        for (int i = 0; i < 16; i++) {
            if (digest[i] != hashed_string[i]) {
                match = false;
                break;
            }
        }

        // If match found, store password and print result
        if (match) {
            if(atomicExch(found, 1) == 0) {
                for (int i = 0; i < PASSWORD_LENGTH; i++) {
                    correct_password[i] = candidate_string[i];
                }
                correct_password[PASSWORD_LENGTH] = '\0';

                printf("Match found! The password is: %s\n", correct_password);
                printf("The thread index is: %llu\n", (unsigned long long)current_index);
                printf("The computed digest is: ");
                for (int i = 0; i < 16; i++) {
                    printf("%02x", digest[i]);
                }
                printf("\n");
            }
            return;
        }
    }
}
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <cuda_runtime.h>


// max size of block 1024 bytes
#define BLOCK_SIZE 256
#define PASSWORD_LENGTH 8

// MD5 digest is 128 bits = 16 bytes.
// (If you later store the digest as hex text, that's 32 chars + '\0' instead.)
#define MD5_DIGEST_LENGTH 16

//Functions definitions

#define F(x,y,z) ((x&y) | (~x & z))
#define G(x,y,z) ((x&z) | (y & ~z))
#define H(x,y,z) (x ^ y ^ z)
#define I(x,y,z) (y ^ (x | ~z))
#define LEFTROTATE(x,c) (x << c) | (x << 32-c)

__constant__ char charSet[] = 
{'a','b','c','d','e','f','g','h','i','j','k','l','m',
 'n','o','p','q','r','s','t','u','v','w','x','y','z',
 'A','B','C','D','E','F','G','H','I','J','K','L','M',
 'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'};

/*
    This function is responsible for generating a unique string from the index.
    string - Representing the string the function generated.
    index - Representing the unique index.
*/
__device__ void generate_string(uint64_t index, char *string){

    for (int i = PASSWORD_LENGTH - 1; i >= 0 ; i-- ){
        string[i] = charSet[index % 52];
        index /= 52;
    }

    string[PASSWORD_LENGTH] = '\0';
}

/*
    This Kernal is reponsible for hashing the input string using the MD5 algorithm
    input_string - Representing the 8 character password string
    hashed_ouput - Representing the hashed output string.
*/
__global__ void compute_md5(char *input_string, char* hashed_output) { 
    
    // calculates the global thread ID
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    
    // each thread will generate a unique string based on its index
    char candidate_string[PASSWORD_LENGTH + 1]; 

    // generates unique string for each thread
    generate_string(idx, candidate_string);
    
    // 1. Append padding bits
    uint64_t block[64] = {0}; //Representing our 512 bit block. Init with 0

    memcpy(block, candidate_string, 8); //Copy the string into the message portion of the 512 bit block (8 Bytes)
    //Add the 1 bit
    block[8] = 0x80; // 10000000

    // 2. append the original length of message.
    uint64_t length = 64;
    memcpy(block + 56, &length, 8);

    // 3. Initialize MD buffer
    uint32_t A = 0x67452301;
    uint32_t B = 0xEFCDAB89;
    uint32_t C = 0x98BADCFE;
    uint32_t D = 0x10325476;

    // 4. process message in 16-word blocks (512 bits)
    uint32_t words[16]; // We now 16, 32 bit numbers (512 bits)
    
    for( int i = 0; i < 16; i++){
        words[i] = (uint32_t)block[i*4] |
                    ((uint32_t)block[i*4 + 1] << 8) |
                    ((uint32_t)block[i*4 + 2] << 16) |
                    ((uint32_t)block[i*4 + 3] << 24);
    }

    uint32_t AA = A;
    uint32_t BB = B;
    uint32_t CC = C;
    uint32_t DD = D;


    // T constants for MD5
    static const uint32_t T[64] = {
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

//process each 16 word block (512 bits)


    for(int i = 0; i < 16; i += 4){
        //Rounds of MD5
       
        // Round 1
        A = B + LEFTROTATE(A + F(B,C,D) + words[i] + T[i], 7);
        D = A + LEFTROTATE(D + F(A,B,C) + words[i + 1] + T[i + 1], 12);
        C = D + LEFTROTATE(C + F(D,A,B) + words[i + 2] + T[i + 2], 17);
        B = C + LEFTROTATE(B + F(C,D,A) + words[i + 3] + T[i + 3], 22);
    }
    // Round 2
    for( int i = 0; i < 16; i += 4){
        
        int k0 = (5 * i) + 1 % 16;
        int k1 = (5 * (i+1) + 1) % 16;
        int k2 = (5 * (i+2) + 1) % 16;
        int k3 = (5 * (i+3) + 1) % 16;
        A = B + LEFTROTATE(A + G(B,C,D) + words[k0] + T[16+ i], 5);
        D = A + LEFTROTATE(D + G(A,B,C) + words[k1] + T[16 + i + 1], 9);
        C = D + LEFTROTATE(C + G(D,A,B) + words[k2] + T[16 + i + 2], 14);
        B = C + LEFTROTATE(B + G(C,D,A) + words[k3] + T[16 + i + 3], 20);
        
    }

    // Round 3
    for( int i = 0; i < 16; i += 4){
        int k0 = (3 * i + 5) % 16;
        int k1 = (3 * (i+1) + 5) % 16;
        int k2 = (3 * (i+2) + 5) % 16;
        int k3 = (3 * (i+3) + 5) % 16;
        A = B + LEFTROTATE(A + H(B,C,D) + words[k0] + T[32 + i], 4);
        D = A + LEFTROTATE(D + H(A,B,C) + words[k1] + T[32 + i + 1], 11);
        C = D + LEFTROTATE(C + H(D,A,B) + words[k2] + T[32 + i + 2], 16);
        B = C + LEFTROTATE(B + H(C,D,A) + words[k3] + T[32 + i + 3], 23);
    }
    // Round 4
    for( int i = 0; i < 16; i += 4){
        int k0 = (7 * i) % 16;
        int k1 = (7 * (i+1)) % 16;
        int k2 = (7 * (i+2)) % 16;
        int k3 = (7 * (i+3)) % 16;
        A = B + LEFTROTATE(A + I(B,C,D) + words[k0] + T[48 + i], 6);
        D = A + LEFTROTATE(D + I(A,B,C) + words[k1] + T[48 + i + 1], 10);
        C = D + LEFTROTATE(C + I(D,A,B) + words[k2] + T[48 + i + 2], 15);
        B = C + LEFTROTATE(B + I(C,D,A) + words[k3] + T[48 + i + 3], 21);
    }

    //We perform the final additions(Increment each of the four registers by the value it had before this block was started)
    A += AA;
    B += BB;
    C += CC;
    D += DD;

    //Store the result in the output array (little-endian)
    hashed_output[0] = A & 0xFF;
    hashed_output[1] = (A >> 8) & 0xFF;
    hashed_output[2] = (A >> 16) & 0xFF;
    hashed_output[3] = (A >> 24) & 0xFF;
    hashed_output[4] = B & 0xFF;
    hashed_output[5] = (B >> 8) & 0xFF;
    hashed_output[6] = (B >> 16) & 0xFF;
    hashed_output[7] = (B >> 24) & 0xFF;
    hashed_output[8] = C & 0xFF;
    hashed_output[9] = (C >> 8) & 0xFF; 
    hashed_output[10] = (C >> 16) & 0xFF;
    hashed_output[11] = (C >> 24) & 0xFF;
    hashed_output[12] = D & 0xFF;
    hashed_output[13] = (D >> 8) & 0xFF;
    hashed_output[14] = (D >> 16) & 0xFF;
    hashed_output[15] = (D >> 24) & 0xFF;
    hashed_output[16] = '\0'; // Null-terminate the output string

}

int main () {

    //size of vectors
    

    //host input vectors
    char *h_input = (char *)malloc(BLOCK_SIZE * sizeof(char));
    //host output vector
    unsigned char *h_output = (unsigned char *)malloc(MD5_DIGEST_LENGTH * sizeof(unsigned char));

    //device input vectors
    char *d_input;
    //device output vector
    unsigned char *d_output;

    //allocate memory on the device
    cudaMalloc((void **)&d_input, BLOCK_SIZE * sizeof(char));
    cudaMalloc((void **)&d_output, MD5_DIGEST_LENGTH * sizeof(unsigned char));

    //copy host input data to device
    cudaMemcpy(d_input, h_input, BLOCK_SIZE * sizeof(char), cudaMemcpyHostToDevice);

    int device = 0;
    cudaGetDevice(&device);
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, device);

    // setup gridsize and blocksize
    int numBlocks = prop.multiProcessorCount * 32;

    // launch the kernel
    generate_string<<<numBlocks, BLOCK_SIZE>>>();

    // copy the result back to host
    cudaMemcpy(h_output, d_output, MD5_DIGEST_LENGTH * sizeof(unsigned char), cudaMemcpyDeviceToHost);

    // print the result

    

}
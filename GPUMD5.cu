#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <cuda_runtime.h>


// max size of block 1024 bytes
#define BLOCK_SIZE 256
#define PASSWORD_LENGTH 8

//Functions definitions

#define F(x,y,z) ((x&y) | (~x & z))
#define G(x,y,z) ((x&z) | (y & ~z))
#define H(x,y,z) (x ^ y ^ z)
#define I(x,y,z) (y ^ (x | ~z))

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

    

    
    // Here you would implement the MD5 hashing algorithm to hash the candidate_string

    
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
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <cuda_runtime.h>
#include <time.h>

// max size of block 1024 bytes
#define BLOCK_SIZE 256
#define PASSWORD_LENGTH 8

// MD5 digest is 128 bits = 16 bytes.
// (If you later store the digest as hex text, that's 32 chars + '\0' instead.)
#define MD5_DIGEST_LENGTH 16


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
__constant__ const uint32_t T[64] = {
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
    hashed_string - Representing the 8 character password hashed.
    correct_password - Representing the hashed output string.
*/
__global__ void compute_md5(unsigned char *hashed_string, char *correct_password) { 
    
    // calculates the global thread ID
    uint64_t idx =(uint64_t)blockIdx.x * blockDim.x + threadIdx.x;    
    // each thread will generate a unique string based on its index
    char candidate_string[PASSWORD_LENGTH + 1]; 

    // generates unique string for each thread
    generate_string(idx, candidate_string);
    
    // 1. Append padding bits
    uint8_t block[64] = {0}; //Representing our 512 bit block. Init with 0

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
    //We save the initial values of A, B, C, D to add them back after processing the block
    uint32_t AA = A;
    uint32_t BB = B;
    uint32_t CC = C;
    uint32_t DD = D;


    //process each 16 word block (512 bits)
    for(int i = 0; i < 64; i++){

        //Determine the function to use and the index g of the word to use
        uint32_t f;
        int g;
            
        if(i < 16){
            f = F(B,C,D);
            g = i;
        }
        else if(i < 32){
            f = G(B,C,D);
            g = (5*i + 1) % 16;
        }
        else if(i < 48){
            f = H(B,C,D);
            g = (3*i + 5) % 16;
        }
        else{
            f = I(B,C,D);
            g = (7*i) % 16;
        }

        uint32_t temp = D;
        D = C;
        C = B;
        B = B + LEFTROTATE(A + f + T[i] + words[g], shift[i]);
        A = temp;
    }
    //We perform the final additions(Increment each of the four registers by the value it had before this block was started)
    A += AA;
    B += BB;
    C += CC;
    D += DD;

    
    //Store the result in the output array (little-endian)
    unsigned char digest[16];

    digest[0] = A & 0xFF;
    digest[1] = (A >> 8) & 0xFF;
    digest[2] = (A >> 16) & 0xFF;
    digest[3] = (A >> 24) & 0xFF;

    digest[4] = B & 0xFF;
    digest[5] = (B >> 8) & 0xFF;
    digest[6] = (B >> 16) & 0xFF;
    digest[7] = (B >> 24) & 0xFF;

    digest[8]  = C & 0xFF;
    digest[9]  = (C >> 8) & 0xFF;
    digest[10] = (C >> 16) & 0xFF;
    digest[11] = (C >> 24) & 0xFF;

    digest[12] = D & 0xFF;
    digest[13] = (D >> 8) & 0xFF;
    digest[14] = (D >> 16) & 0xFF;
    digest[15] = (D >> 24) & 0xFF;

    //Compare the computed digest with the input hash
    bool match = true;
    for(int i = 0; i < 16; i++){
        if(digest[i] != (unsigned char)hashed_string[i]){
            match = false;
            break;
        }
    }

    //If a match is found, copy the candidate string to the output and print the result
    if(match){

        for(int i = 0; i < PASSWORD_LENGTH; i++){
            correct_password[i] = candidate_string[i];
        }
        correct_password[8] = '\0';

        printf("Match found! The password is: %s\n", correct_password);
        printf("The thread index is: %llu\n", idx);
        printf("The computed digest is: ");

        for(int i = 0; i < 16; i++) {
            printf("%02x", digest[i]);
        }
        printf("\n");
    
    }
}


int main () {

    //host input and output vectors
    // Password: bXirrMvB - 2 trillionth password hex representation of 0cf7a2bb526670cfd4ac53b7ee627eec
    unsigned char h_input[16] = {
   0x0c, 0xf7, 0xa2, 0xbb,
    0x52, 0x66, 0x70, 0xcf,
    0xd4, 0xac, 0x53, 0xb7,
    0xee, 0x62, 0x7e, 0xec
    };
    unsigned char *h_output = (unsigned char *)malloc(9); //Size for the single hash
    
    //device input and output vectors
    unsigned char *d_input;
    char *d_output;

    //allocate memory on the device
    cudaMalloc((void **)&d_input, 16);
    cudaMalloc((void **)&d_output, 9 * sizeof(unsigned char));

    //copy host input data to device
    cudaMemcpy(d_input, h_input, 16, cudaMemcpyHostToDevice);

    // measure the time taken by the kernel
    time_t start, end;
    time(&start);

    // launch the kernel
    compute_md5<<< 2147483647 , 1024>>>(d_input, d_output);

    cudaDeviceSynchronize(); 

    // copy the result back to host
    cudaMemcpy(h_output, d_output, 9, cudaMemcpyDeviceToHost);
    time(&end);
    double time_taken = difftime(end, start);
    printf("Time taken: %f seconds\n", time_taken);
}
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <openssl/md5.h>
#include <time.h>

static double elapsed_seconds(struct timespec start, struct timespec end) {
    return (double)(end.tv_sec - start.tv_sec) + (double)(end.tv_nsec - start.tv_nsec) / 1e9;
}

#define MAX_PASSWORD_LENGTH 8 //Bytes or 64 bits
#define CHARSET_SIZE 52 

// Function to compute the total number of possible passwords given a charset size and password length
uint64_t compute_total_passwords(int charset_size, int password_length) {

    uint64_t total = 0;
    uint64_t power = 1;

    for(int i = 1; i <= password_length; i++) {
        power *= charset_size;
        total += power;
    }
    return total;
}

/* Function to generate a password based on an index and charset.
Basically serves an index to each possible password so that when grabbing the next index
if that password hash matches the target hash, we can easily pull it with its index */
void generate_password(uint64_t index, int charset_size, int max_password_length, char* charset, char* output) {

    // Calculate the total number of passwords for each length
    uint64_t prev_count = 0;
    // This variable will hold the number of passwords for the current length
    uint64_t count_for_length = 1;
    // This variable will determine the length of the password we are generating
    int length = 0;

    // Determine the length of the password based on the index
    while (length < max_password_length) {
        count_for_length *= charset_size;
        if (index < prev_count + count_for_length) {
            break;
        }
        prev_count += count_for_length;
        length++;
    }

    // Generate the password based on the index and charset
    for (int i = 0; i < length; i++) {
        output[i] = charset[(index / count_for_length) % charset_size];
        count_for_length /= charset_size;
    }
    output[length] = '\0';
}

/*
    Generate 8 char length password from a given index.
    ouput - Representing the string generated (8 Characters in length)
*/
void generate_from_index(uint64_t index, char* output){

    const char charset[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

    for (int i = MAX_PASSWORD_LENGTH - 1; i >= 0; i--){
        output[i] = charset[index % CHARSET_SIZE];
        index /= CHARSET_SIZE;
    }

    output[MAX_PASSWORD_LENGTH] = '\0';
}

int main(int argc, char *argv[]) {

    
    printf("This is the CPU implementation of the MD5 password cracker.\n");

     if (argc != 2){
        printf("Usage: %s\n <MD5_HASH>", argv[0]);
        return 1;
    }


    unsigned char hash[16]; 
    for (int i = 0; i < 16; i++) {
        sscanf(argv[1] + 2*i, "%2hhx", &hash[i]);
    }

    //Now find the hash
    struct timespec startTime, endTime;
    clock_gettime(CLOCK_MONOTONIC, &startTime);
    for (uint64_t i = 0; i < pow(52, 8); i++){

        unsigned char hashed_guess[16];
        unsigned char string[MAX_PASSWORD_LENGTH + 1];

        generate_from_index(i, string);
        //CHECK GUESS
        MD5((const unsigned char*) string, strlen(string), hashed_guess);

        if(memcmp(hash, hashed_guess, 16) == 0){
            printf("Match Found! The password is: %s\n", string);
            printf("The thread index is: %lu\n", i);
            break;
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &endTime);
    double timeTaken = elapsed_seconds(startTime, endTime);
    printf("The Computed Digest is : %s\n", argv[1]);
    printf("Sequential Time: %.6f seconds\n", timeTaken);
}
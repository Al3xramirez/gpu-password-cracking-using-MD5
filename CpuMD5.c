#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <openssl/md5.h>

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

int main(){

    printf("This is a CPU implementation of MD5\n");

    unsigned char target[] = "password"; 
    uint8_t hash[16];

    uint64_t index = 1;
    char string[MAX_PASSWORD_LENGTH + 1];

    generate_from_index(index, string);

    printf("%s\n", string);

    MD5((const unsigned char* ) target, strlen(target), hash);

    for(int i = 0; i < 16; i++){
        printf("%02x", hash[i]);
    }
    printf("\n");
    

}
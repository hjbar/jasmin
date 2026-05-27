#ifndef CHACHA20XOR_SHARED_H
#define CHACHA20XOR_SHARED_H


// IMPORT THE BENCH RUNNER
#include "bench_runner.h"


// DECLARE THE X86-64 PROGRAM
extern int CHACHAXOR_FUNC(uint8_t *output, const uint8_t *input, uint64_t input_length, const uint8_t *nonce, const uint8_t *key);


// INPUTS
static uint8_t *input_bytes;
static uint8_t *output_bytes;
static uint64_t length;
static uint8_t nonce[12];
static uint8_t key[32];


// INIT ARGS
void bench_init(int argc, char *argv[]) {
  const char *input_raw = argv[3];
  length = strlen(input_raw);
  input_bytes  = malloc(length > 0 ? length : 1);
  output_bytes = malloc(length > 0 ? length : 1);
  memcpy(input_bytes, input_raw, length);
  hex_to_bytes(argv[4], nonce, 12);
  hex_to_bytes(argv[5], key, 32);
}


// BENCHMARK FUNCTION
inline void bench_run(void) {
  CHACHAXOR_FUNC(output_bytes, input_bytes, length, nonce, key);
}


// PRINT RESULT FUNCTION
void bench_print_result(int verbose, char *argv[]) {
  if (verbose) {
    printf("Result        : ");
    for (uint64_t i = 0; i < length; i++) printf("%02x", output_bytes[i]);
    printf("\n");
  }
}


// FREE FUNCTION
void bench_cleanup(void) {
  free(input_bytes);
  free(output_bytes);
}


#endif

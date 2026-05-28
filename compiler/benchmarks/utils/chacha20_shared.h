#ifndef CHACHA20_SHARED_H
#define CHACHA20_SHARED_H


// IMPORT THE BENCH RUNNER
#include "bench_runner.h"


// DECLARE THE X86-64 PROGRAM
extern int CHACHA_FUNC(uint8_t *stream, uint64_t stream_length, const uint8_t *nonce, const uint8_t *key);


// INPUTS
static uint64_t length;
static uint8_t *stream;
static uint8_t nonce[12];
static uint8_t key[32];


// INIT ARGS
void bench_init(int argc, char *argv[]) {
  length = (uint64_t)atoll(argv[3]);
  stream = calloc(1, length > 0 ? length : 1);
  hex_to_bytes(argv[4], nonce, 12);
  hex_to_bytes(argv[5], key, 32);
}


// BENCHMARK FUNCTION
inline void bench_run(void) {
  CHACHA_FUNC(stream, length, nonce, key);
}


// PRINT RESULT FUNCTION
void bench_print_result(int verbose, char *argv[]) {
  if (verbose) {
    printf("Result        : ");
    for (int i = 0; i < length; i++) printf("%02x", stream[i]);
    printf("\n");
  }
}


// FREE FUNCTION
void bench_cleanup(void) {
  free(stream);
}


#endif

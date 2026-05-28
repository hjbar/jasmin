#ifndef SHA256_SHARED_H
#define SHA256_SHARED_H


// IMPORT THE BENCH RUNNER
#include "bench_runner.h"


// DECLARE THE X86-64 PROGRAM
extern int SHA_FUNC(uint8_t *hash, const uint8_t *input, uint64_t input_length);


// INPUTS
static uint8_t hash[32];
static const uint8_t *input;
static uint64_t input_length;


// INIT ARGS
void bench_init(int argc, char *argv[]) {
  input = (const uint8_t *)argv[3];
  input_length = strlen((const char*)input);
}


// BENCHMARK FUNCTION
inline void bench_run(void) {
    SHA_FUNC(hash, input, input_length);
}


// PRINT RESULT FUNCTION
void bench_print_result(int verbose, char *argv[]) {
  if (verbose) {
    printf("Input         : \"%s\" (%llu bytes)\n", argv[3], (unsigned long long)input_length);
    printf("Hash          : ");
    for (int i = 0; i < 32; i++) printf("%02x", hash[i]);
    printf("\n");
  }
}


// FREE FUNCTION
void bench_cleanup(void) {
  return;
}


#endif

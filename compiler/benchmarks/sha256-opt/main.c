// Import libraries
#define _POSIX_C_SOURCE 199309L
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include <time.h>

// Declare the X86-64 program
extern int jade_hash_sha256_amd64_ref(uint8_t *hash, const uint8_t *input, uint64_t input_length);

// Main
int main(int argc, char *argv[]) {
  // Parse the command line
  if (argc < 5) {
    printf("Usage: %s <nb_repeat> <nb_iterations> <input_string> <verbose>\n", argv[0]);
    return 1;
  }

  // Init args
  const uint64_t nb_repeat = (uint64_t)atoll(argv[1]);
  const uint64_t nb_iter = (uint64_t)atoll(argv[2]);
  const uint64_t warmup_iter = nb_iter / 10;
  uint8_t hash[32];
  const uint8_t *input = (const uint8_t *)argv[3];
  const uint64_t input_length = strlen((const char*)input);
  const uint64_t VERBOSE = (uint64_t)atoll(argv[4]);

  double *times = malloc(nb_repeat * sizeof(double));
  if (!times) return 1;

  // Warmup
  for (int i = 0; i < warmup_iter; i++) {
    jade_hash_sha256_amd64_ref(hash, input, input_length);
  }

  // Benchmark
  for (int i = 0; i < nb_repeat; i++) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int j = 0; j < nb_iter; j++) {
      jade_hash_sha256_amd64_ref(hash, input, input_length);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    times[i] = (end.tv_sec - start.tv_sec) + ((end.tv_nsec - start.tv_nsec) / 1e9);
  }

  // Compute the result
  double sum = 0;
  for (int i = 0; i < nb_repeat; i++) sum += times[i];
  double mean = sum / nb_repeat;

  double sum_sq_diff = 0;
  for (int i = 0; i < nb_repeat; i++) {
    double diff = times[i] - mean;
    sum_sq_diff += diff * diff;
  }
  double variance = sum_sq_diff / nb_repeat;
  double std_dev = sqrt(variance);

  {
    printf("Samples       : %llu\n"                  , (unsigned long long)nb_repeat);
    printf("Iterations    : %llu\n"                  , (unsigned long long)nb_iter);
    printf("Mean time     : %.6fs\n"                 , mean);
    printf("Std Deviation : %.6fs (%.6f%% of mean)\n", std_dev, ((std_dev / mean) * 100));
    printf("Avg per call  : %.6fns\n"                , ((mean * 1e9) / nb_iter));
  }
  if (VERBOSE) {
    printf("Input         : \"%s\" (%llu bytes)\n"   , argv[3], (unsigned long long)input_length);
    printf("Hash          : "); for (int i = 0; i < 32; i++) printf("%02x", hash[i]); printf("\n");
  }

  free(times);
  return 0;
}

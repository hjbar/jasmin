// Import libraries
#define _POSIX_C_SOURCE 199309L
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <math.h>
#include <time.h>

// Declare the X86-64 program
extern void gimli(uint32_t *state);

// Main
int main(int argc, char *argv[]) {
  // Parse the command line
  if (argc < 4) {
    printf("Usage: %s <nb_repeat> <nb_iterations> <verbose>\n", argv[0]);
    return 1;
  }

  // Init args
  const uint64_t nb_repeat = (uint64_t)atoll(argv[1]);
  const uint64_t nb_iter = (uint64_t)atoll(argv[2]);
  const uint64_t VERBOSE = (uint64_t)atoll(argv[3]);
  const uint64_t warmup_iter = nb_iter / 10;
  uint32_t input[12]; for (int i = 0 ;i < 12; ++i) input[i] = i * i * i + i * 0x9e3779b9;
  uint32_t state[12]; for (int i = 0 ;i < 12; ++i) state[i] = i * i * i + i * 0x9e3779b9;

  double *times = malloc(nb_repeat * sizeof(double));
  if (!times) return 1;

  // Warmup
  for (int i = 0; i < warmup_iter; i++) {
    gimli(state);
  }

  // Benchmark
  for (int i = 0; i < nb_repeat; i++) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int j = 0; j < nb_iter; j++) {
      gimli(state);
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
    printf("Input         : "); for (int i = 0; i < 12; ++i) printf("%08x ", input[i]); printf("\n");
    printf("Result        : "); for (int i = 0; i < 12; ++i) printf("%08x ", state[i]); printf("\n");
  }

  free(times);
  return 0;
}

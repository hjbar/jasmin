#ifndef BENCH_RUNNER_H
#define BENCH_RUNNER_H


// IMPORT LIBRARIES
#define _POSIX_C_SOURCE 199309L
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include <time.h>


// Convert hex to bytes
static inline void hex_to_bytes(const char *hex, uint8_t *bytes, size_t len) {
  for (size_t i = 0; i < len; i++) {
    sscanf(hex + 2 * i, "%02hhx", &bytes[i]);
  }
}


// CONTRACT
void bench_init(int argc, char *argv[]);
void bench_run(void);
void bench_print_result(int verbose, char *argv[]);
void bench_cleanup(void);


// MAIN
int main(int argc, char *argv[]) {

  // PARSE THE COMMAND LINE
  if (argc < 3) {
    fprintf(stderr, "Usage minimal: %s <nb_repeat> <nb_iterations> ...\n", argv[0]);
    return 1;
  }


 // INIT ARGS
  const uint64_t nb_repeat = (uint64_t)atoll(argv[1]);
  const uint64_t nb_iter   = (uint64_t)atoll(argv[2]);
  const uint64_t warmup_iter = nb_iter / 10;

  const int verbose = atoi(argv[argc - 1]);

  bench_init(argc, argv);

  double *times = (double *)malloc(nb_repeat * sizeof(double));
  if (!times) return 1;


  // WARMUP
  for (uint64_t i = 0; i < warmup_iter; i++) {
    bench_run();
  }


  // BENCHMARK
  for (uint64_t i = 0; i < nb_repeat; i++) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (uint64_t j = 0; j < nb_iter; j++) {
      bench_run();
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    times[i] = (end.tv_sec - start.tv_sec) + ((end.tv_nsec - start.tv_nsec) / 1e9);
  }


  // Compute the result
  double sum = 0;
  for (uint64_t i = 0; i < nb_repeat; i++) sum += times[i];
  double mean = sum / nb_repeat;

  double sum_sq_diff = 0;
  for (uint64_t i = 0; i < nb_repeat; i++) {
    double diff = times[i] - mean;
    sum_sq_diff += diff * diff;
  }
  double variance = sum_sq_diff / nb_repeat;
  double std_dev = sqrt(variance);


  // PRINT
  printf("Samples       : %llu\n"                  , (unsigned long long)nb_repeat    );
  printf("Iterations    : %llu\n"                  , (unsigned long long)nb_iter      );
  printf("Mean time     : %.6fs\n"                 , mean                             );
  printf("Std Deviation : %.6fs (%.6f%% of mean)\n", std_dev, ((std_dev / mean) * 100));
  printf("Avg per call  : %.6fns\n"                , ((mean * 1e9) / nb_iter)         );
  bench_print_result(verbose, argv);


  // FREE
  bench_cleanup();
  free(times);


  // RETURN
  return 0;

}


#endif

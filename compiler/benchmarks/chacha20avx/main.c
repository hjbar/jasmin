// Import libraries
#define _POSIX_C_SOURCE 199309L
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include <time.h>

// Declare the X86-64 program
extern int jade_stream_chacha_chacha20_amd64_avx(uint8_t *stream, uint64_t stream_length, const uint8_t *nonce, const uint8_t *key);

// Convert hex to bytes
void hex_to_bytes(const char *hex, uint8_t *bytes, size_t len) {
  for (size_t i = 0; i < len; i++) {
    sscanf(hex + 2 * i, "%02hhx", &bytes[i]);
  }
}

// Main
int main(int argc, char *argv[]) {
  // Parse the command line
  if (argc < 7) {
    printf("Usage: %s <nb_repeat> <nb_iterations> <input_length> <input_nonce> <input_key> <verbose>\n", argv[0]);
    return 1;
  }

  // Init args
  const uint64_t nb_repeat = (uint64_t)atoll(argv[1]);
  const uint64_t nb_iter = (uint64_t)atoll(argv[2]);
  const uint64_t length = (uint64_t)atoll(argv[3]);
  const char *nonce_hex = argv[4];
  const char *key_hex = argv[5];
  const uint64_t VERBOSE = (uint64_t)atoll(argv[6]);

  const uint64_t warmup_iter = nb_iter / 10;
  uint8_t *stream = calloc(1, length > 0 ? length : 1);
  uint8_t nonce[12] = {0};
  hex_to_bytes(nonce_hex, nonce, 12);
  uint8_t key[32] = {0};
  hex_to_bytes(key_hex, key, 32);

  double *times = malloc(nb_repeat * sizeof(double));
  if (!times) return 1;

  // Warmup
  for (int i = 0; i < warmup_iter; i++) {
    jade_stream_chacha_chacha20_amd64_avx(stream, length, nonce, key);
  }

  // Benchmark
  for (int i = 0; i < nb_repeat; i++) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int j = 0; j < nb_iter; j++) {
      jade_stream_chacha_chacha20_amd64_avx(stream, length, nonce, key);
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
    printf("Result        : "); for (int i = 0; i < length; i++) printf("%02x", stream[i]); printf("\n");
  }

  free(stream);
  free(times);
  return 0;
}

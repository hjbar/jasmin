// IMPORT THE BENCH RUNNER
#include "../utils/bench_runner.h"


// DECLARE THE X86-64 PROGRAM
extern void gimli(uint32_t *state);


// INPUTS
static uint32_t input[12];
static uint32_t state[12];


// INIT ARGS
void bench_init(int argc, char *argv[]) {
  for (int i = 0; i < 12; ++i) {
    input[i] = i * i * i + i * 0x9e3779b9;
    state[i] = i * i * i + i * 0x9e3779b9;
  }
}


// BENCHMARK FUNCTION
inline void bench_run(void) {
    gimli(state);
}


// PRINT RESULT FUNCTION
void bench_print_result(int verbose, char *argv[]) {
  if (verbose) {
    printf("Input         : ");
    for (int i = 0; i < 12; ++i) printf("%08x ", input[i]);
    printf("\n");

    printf("Result        : ");
    for (int i = 0; i < 12; ++i) printf("%08x ", state[i]);
    printf("\n");
  }
}


// FREE FUNCTION
void bench_cleanup(void) {
  return;
}

// IMPORT THE BENCH AND WASM RUNNER
#include "../../utils/bench_runner.h"
#include "../../utils/wasm_runner.h"


// CONFIG
#define WASM_FILE_PATH "../prog/gimli_wasm.wasm"
#define WASM_FUNC_NAME "gimli"
#define WASM_USE_I64   0


// GLOBALS
static wasm_env_t wasm_env;
static wasmtime_func_t gimli_func;
static wasmtime_val_raw_t call_args[1];

static uint32_t state_offset;
static uint32_t input_state[12];
static uint8_t *mem_data;


// INIT ARGS
void bench_init(int argc, char *argv[]) {

  if (argc < 4) {
    fprintf(stderr, "Usage: %s <nb_repeat> <nb_iterations> <verbose>\n", argv[0]);
    exit(1);
  }

  // RESOLVE PATH & WASMTIME INIT
  char resolved_wasm_path[PATH_MAX];
  wasm_resolve_exe_relative_path(WASM_FILE_PATH, resolved_wasm_path, sizeof(resolved_wasm_path));

  wasm_env_init(&wasm_env, resolved_wasm_path, 1024);
  gimli_func = wasm_env_get_func(&wasm_env, WASM_FUNC_NAME);
  mem_data = wasm_env_memory_data(&wasm_env);

  // WASM INIT
  state_offset = 50000;

  size_t mem_size = wasmtime_memory_data_size(wasm_env.context, &wasm_env.memory);
  if (state_offset + 12 * sizeof(uint32_t) > mem_size) {
    fprintf(stderr, "Error : state doesn't fit in the Wasm linear memory\n");
    exit(1);
  }

  uint32_t *wasm_state = (uint32_t *)(mem_data + state_offset);
  for (uint32_t i = 0; i < 12; ++i) {
    uint32_t val = i * i * i + i * 0x9e3779b9u;
    input_state[i] = val;
    wasm_state[i]  = val;
  }

  // PREPARE INPUT ARGS
#if WASM_USE_I64
  call_args[0].i64 = (int64_t)state_offset;
#else
  call_args[0].i32 = (int32_t)state_offset;
#endif

  return;

}


// BENCHMARK FUNCTION
void bench_run(void) {

  wasm_trap_t *trap = NULL;
  wasmtime_func_call_unchecked(wasm_env.context, &gimli_func, call_args, 1, &trap);
  return;

}


// PRINT RESULT FUNCTION
void bench_print_result(int verbose, char *argv[]) {

  (void)argv;

  if (verbose) {
    mem_data = wasm_env_memory_data(&wasm_env);
    const uint32_t *wasm_state = (const uint32_t *)(mem_data + state_offset);

    printf("Input         : ");
    for (int i = 0; i < 12; ++i) {
      printf("%08x ", input_state[i]);
    }
    printf("\n");

    printf("Result        : ");
    for (int i = 0; i < 12; ++i) {
      printf("%08x ", wasm_state[i]);
    }
    printf("\n");
  }

  return;

}


// FREE FUNCTION
void bench_cleanup(void) {

  wasm_env_cleanup(&wasm_env);
  return;

}

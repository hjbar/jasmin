#ifndef SHA256_WASM_SHARED_H
#define SHA256_WASM_SHARED_H


// IMPORT THE BENCH AND WASM RUNNER
#include "bench_runner.h"
#include "wasm_runner.h"


/*
Macros to define in the C main file before the inclusion :
  - WASM_FILE_PATH : path to the .wasm (ex: "prog/sha256-opt_wasm.wasm")
  - WASM_FUNC_NAME : exported function name (ex: "jade_hash_sha256_amd64_ref")
  - WASM_USE_I64   : 0 for i32 mode (by default), 1 for i64 mode
*/


// GLOBALS
#ifndef WASM_USE_I64
#define WASM_USE_I64 0
#endif


static wasm_env_t wasm_env;
static wasmtime_func_t sha_func;
static wasmtime_val_raw_t call_args[3];


static uint32_t hash_offset;
static uint32_t input_offset;
static uint64_t input_length;
static uint8_t *mem_data;


// INIT ARGS
void bench_init(int argc, char *argv[]) {

  if (argc < 5) {
    fprintf(stderr, "Usage: %s <nb_repeat> <nb_iterations> <input_string> <verbose>\n", argv[0]);
    exit(1);
  }

  // WASMTIME INIT
  char resolved_wasm_path[PATH_MAX];
  wasm_resolve_exe_relative_path(WASM_FILE_PATH, resolved_wasm_path, sizeof(resolved_wasm_path));

  wasm_env_init(&wasm_env, resolved_wasm_path, 1024);
  sha_func = wasm_env_get_func(&wasm_env, WASM_FUNC_NAME);
  mem_data = wasm_env_memory_data(&wasm_env);

  // WASM INIT
  const char *input_str = argv[3];
  input_length = strlen(input_str);
  hash_offset  = 50000;
  input_offset = hash_offset + 32;

  size_t mem_size = wasmtime_memory_data_size(wasm_env.context, &wasm_env.memory);
  if (input_offset + input_length > mem_size) {
    fprintf(stderr, "Error : input length doesn't fit in the Wasm linear memory\n");
    exit(1);
  }

  memcpy(mem_data + input_offset, input_str, input_length);

  // PREPARE INPUT ARGS INPUTS
#if WASM_USE_I64
  call_args[0].i64 = (int64_t)hash_offset;
  call_args[1].i64 = (int64_t)input_offset;
  call_args[2].i64 = (int64_t)input_length;
#else
  call_args[0].i32 = (int32_t)hash_offset;
  call_args[1].i32 = (int32_t)input_offset;
  call_args[2].i32 = (int32_t)input_length;
#endif

  return;

}


// BENCHMARK FUNCTION
__attribute__((always_inline)) void bench_run(void) {

  wasm_trap_t *trap = NULL;

  wasmtime_func_call_unchecked(wasm_env.context, &sha_func, call_args, 3, &trap);

  return;

}


// PRINT RESULT FUNCTION
void bench_print_result(int verbose, char *argv[]) {

  if (verbose) {
    mem_data = wasm_env_memory_data(&wasm_env);
    printf("Input         : \"%s\" (%llu bytes)\n", argv[3], (unsigned long long)input_length);
    printf("Hash          : ");
    for (int i = 0; i < 32; i++) {
      printf("%02x", mem_data[hash_offset + i]);
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


#endif

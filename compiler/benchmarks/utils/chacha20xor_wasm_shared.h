#ifndef CHACHA20XOR_WASM_SHARED_H
#define CHACHA20XOR_WASM_SHARED_H


// IMPORT THE BENCH AND WASM RUNNER
#include "bench_runner.h"
#include "wasm_runner.h"


/*
Macros to define in the C main file before the inclusion :
  - WASM_FILE_PATH : path to the .wasm (ex: "../prog/chacha20xor_wasm.wasm")
  - WASM_FUNC_NAME : exported function name (ex: "jade_stream_chacha_chacha20_amd64_ref_xor")
  - WASM_USE_I64   : 0 for i32 mode (by default), 1 for i64 mode
*/


// GLOBALS
#ifndef WASM_USE_I64
#define WASM_USE_I64 0
#endif

static wasm_env_t wasm_env;
static wasmtime_func_t chachaxor_func;
static wasmtime_val_raw_t call_args[5];

static uint32_t output_offset;
static uint32_t input_offset;
static uint64_t length;
static uint32_t nonce_offset;
static uint32_t key_offset;
static uint8_t *mem_data;


// INIT ARGS
void bench_init(int argc, char *argv[]) {

  if (argc < 7) {
    fprintf(stderr, "Usage: %s <nb_repeat> <nb_iterations> <input_string> <nonce_hex> <key_hex> <verbose>\n", argv[0]);
    exit(1);
  }

  // RESOLVE PATH & WASMTIME INIT
  char resolved_wasm_path[PATH_MAX];
  wasm_resolve_exe_relative_path(WASM_FILE_PATH, resolved_wasm_path, sizeof(resolved_wasm_path));

  wasm_env_init(&wasm_env, resolved_wasm_path, 1024);
  chachaxor_func = wasm_env_get_func(&wasm_env, WASM_FUNC_NAME);
  mem_data = wasm_env_memory_data(&wasm_env);

  // WASM MEMORY LAYOUT INIT
  const char *input_raw = argv[3];
  length        = strlen(input_raw);
  output_offset = 50000;
  input_offset  = output_offset + (uint32_t)length;
  nonce_offset  = input_offset + (uint32_t)length;
  key_offset    = nonce_offset + 12;

  size_t mem_size = wasmtime_memory_data_size(wasm_env.context, &wasm_env.memory);
  if (key_offset + 32 > mem_size) {
    fprintf(stderr, "Error : buffers don't fit in the Wasm linear memory\n");
    exit(1);
  }

  memset(mem_data + output_offset, 0, length);
  memcpy(mem_data + input_offset, input_raw, length);
  hex_to_bytes(argv[4], mem_data + nonce_offset, 12);
  hex_to_bytes(argv[5], mem_data + key_offset, 32);

  // PREPARE INPUT ARGS
#if WASM_USE_I64
  call_args[0].i64 = (int64_t)output_offset;
  call_args[1].i64 = (int64_t)input_offset;
  call_args[2].i64 = (int64_t)length;
  call_args[3].i64 = (int64_t)nonce_offset;
  call_args[4].i64 = (int64_t)key_offset;
#else
  call_args[0].i32 = (int32_t)output_offset;
  call_args[1].i32 = (int32_t)input_offset;
  call_args[2].i32 = (int32_t)length;
  call_args[3].i32 = (int32_t)nonce_offset;
  call_args[4].i32 = (int32_t)key_offset;
#endif

  return;

}


// BENCHMARK FUNCTION
void bench_run(void) {

  wasm_trap_t *trap = NULL;

  wasmtime_func_call_unchecked(wasm_env.context, &chachaxor_func, call_args, 5, &trap);

  return;

}


// PRINT RESULT FUNCTION
void bench_print_result(int verbose, char *argv[]) {

  (void)argv;

  if (verbose) {
    mem_data = wasm_env_memory_data(&wasm_env);
    printf("Result        : ");
    for (uint64_t i = 0; i < length; i++) {
      printf("%02x", mem_data[output_offset + i]);
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

#ifndef WASM_RUNNER_H
#define WASM_RUNNER_H


// IMPORT LIBRARIES
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <limits.h>
#include <wasm.h>
#include <wasmtime.h>


typedef struct {
  wasm_engine_t *engine;
  wasmtime_store_t *store;
  wasmtime_context_t *context;
  wasmtime_module_t *module;
  wasmtime_memory_t memory;
  wasmtime_instance_t instance;
} wasm_env_t;


static inline void wasm_exit_with_error(const char *msg, wasmtime_error_t *err, wasm_trap_t *trap) {

  fprintf(stderr, "Wasmtime error (%s) :\n", msg);
  wasm_byte_vec_t message;

  if (err != NULL) {
    wasmtime_error_message(err, &message);
    wasmtime_error_delete(err);
  } else if (trap != NULL) {
    wasm_trap_message(trap, &message);
    wasm_trap_delete(trap);
  } else {
    fprintf(stderr, "Unknown error\n");
    exit(1);
  }

  fprintf(stderr, "%.*s\n", (int)message.size, message.data);
  wasm_byte_vec_delete(&message);

  exit(1);

}


static inline void wasm_resolve_exe_relative_path(const char *rel_path, char *out_buf, size_t buf_size) {

  char exe_path[PATH_MAX];

  ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
  if (len == -1) {
    perror("readlink /proc/self/exe");
    exit(1);
  }

  exe_path[len] = '\0';
  char *exe_dir = dirname(exe_path);

  int written = snprintf(out_buf, buf_size, "%s/%s", exe_dir, rel_path);
  if (written < 0 || (size_t)written >= buf_size) {
    fprintf(stderr, "Error : resolved Wasm path is too long\n");
    exit(1);
  }

  return;

}


static inline uint8_t *wasm_read_file(const char *path, size_t *len) {

  FILE *f = fopen(path, "rb");
  if (!f) { perror(path); exit(1); }

  fseek(f, 0, SEEK_END);
  *len = (size_t)ftell(f);
  fseek(f, 0, SEEK_SET);

  uint8_t *buf = (uint8_t *)malloc(*len);
  if (!buf || fread(buf, 1, *len, f) != *len) { perror("fread"); exit(1); }

  fclose(f);
  return buf;

}


static inline void wasm_env_init(wasm_env_t *env, const char *wasm_path, uint64_t initial_pages) {

  env->engine = wasm_engine_new();
  if (!env->engine) {
    fprintf(stderr, "Wasm_engine_t init fails\n");
    exit(1);
  }
  env->store = wasmtime_store_new(env->engine, NULL, NULL);
  env->context = wasmtime_store_context(env->store);

  size_t wasm_len = 0;
  uint8_t *wasm_bytes = wasm_read_file(wasm_path, &wasm_len);
  wasmtime_error_t *err = wasmtime_module_new(env->engine, wasm_bytes, wasm_len, &env->module);
  free(wasm_bytes);
  if (err) wasm_exit_with_error("module compilation", err, NULL);

  wasm_limits_t limits = { .min = initial_pages, .max = wasm_limits_max_default };
  wasm_memorytype_t *mem_type = wasm_memorytype_new(&limits);
  err = wasmtime_memory_new(env->context, mem_type, &env->memory);
  wasm_memorytype_delete(mem_type);
  if (err) wasm_exit_with_error("memory init", err, NULL);

  wasmtime_extern_t import = { .kind = WASMTIME_EXTERN_MEMORY, .of.memory = env->memory };
  wasm_trap_t *trap = NULL;
  err = wasmtime_instance_new(env->context, env->module, &import, 1, &env->instance, &trap);
  if (err || trap) wasm_exit_with_error("module instantiation", err, trap);

  return;

}


static inline wasmtime_func_t wasm_env_get_func(wasm_env_t *env, const char *fn_name) {

  wasmtime_extern_t item;
  if (!wasmtime_instance_export_get(env->context, &env->instance, fn_name, strlen(fn_name), &item) || item.kind != WASMTIME_EXTERN_FUNC) {
    fprintf(stderr, "Wasm export '%s' not found\n", fn_name);
    exit(1);
  }

  return item.of.func;
}


static inline uint8_t *wasm_env_memory_data(wasm_env_t *env) {
  return wasmtime_memory_data(env->context, &env->memory);
}


static inline void wasm_env_cleanup(wasm_env_t *env) {
  wasmtime_module_delete(env->module);
  wasmtime_store_delete(env->store);
  wasm_engine_delete(env->engine);
}


#endif

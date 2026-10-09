#include "../../libjade_c/sha256/sha256_ref.c"
#include <stdint.h>
#include <stddef.h>


#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#define WASM_EXPORT EMSCRIPTEN_KEEPALIVE
#else
#define WASM_EXPORT __attribute__((visibility("default")))
#endif


EMSCRIPTEN_KEEPALIVE
uint32_t jade_hash_sha256_amd64_ref(unsigned char *hash, const unsigned char *input, uint32_t input_length) {
  jade_hash_sha256_amd64_ref_perso(hash, input, input_length);
  return 0;
}

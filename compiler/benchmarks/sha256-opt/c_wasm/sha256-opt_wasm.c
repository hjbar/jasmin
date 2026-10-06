#include <sodium.h>
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
  if (sodium_init() < 0) {
    return 1;
  }

  crypto_hash_sha256(hash, input, input_length);

  return 0;
}

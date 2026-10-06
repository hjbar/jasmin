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
uint32_t jade_stream_chacha_chacha20_amd64_ref_xor(uint8_t *output, const uint8_t *input, uint32_t input_length, const uint8_t *nonce, const uint8_t *key) {
  if (sodium_init() < 0) {
    return -1;
  }

  crypto_stream_chacha20_xor(output, input, input_length, nonce, key);

  return 0;
}

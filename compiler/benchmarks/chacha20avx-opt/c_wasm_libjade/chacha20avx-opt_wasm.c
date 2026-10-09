#include "../../libjade_c/chacha20avx/chacha20avx_ref.c"
#include <stdint.h>
#include <stddef.h>


#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#define WASM_EXPORT EMSCRIPTEN_KEEPALIVE
#else
#define WASM_EXPORT __attribute__((visibility("default")))
#endif


EMSCRIPTEN_KEEPALIVE
uint32_t jade_stream_chacha_chacha20_amd64_avx(uint8_t *stream, uint32_t stream_length, const uint8_t *nonce, const uint8_t *key) {
  jade_stream_chacha_chacha20_amd64_avx_perso(stream, stream_length, nonce, key);
  return 0;
}

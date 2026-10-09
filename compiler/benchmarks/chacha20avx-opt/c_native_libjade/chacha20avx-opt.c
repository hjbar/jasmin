#define CHACHA_FUNC jade_stream_chacha_chacha20_amd64_avx
#include "../../utils/chacha20_shared.h"
#include "../../libjade_c/chacha20avx/chacha20avx_ref.c"
#include <stdint.h>
#include <stddef.h>


// Declare the libsodium wrapper
int CHACHA_FUNC(uint8_t *stream, uint64_t stream_length, const uint8_t *nonce, const uint8_t *key) {
  jade_stream_chacha_chacha20_amd64_avx_perso(stream, stream_length, nonce, key);
  return 0;
}

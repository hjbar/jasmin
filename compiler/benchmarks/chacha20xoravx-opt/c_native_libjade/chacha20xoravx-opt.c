#define SHA_FUNC jade_stream_chacha_chacha20_amd64_avx_xor
#include "../../utils/chacha20xor_shared.h"
#include "../../libjade_c/chacha20avx/chacha20avx_ref.c"
#include <stdint.h>
#include <stddef.h>


// Declare the libsodium wrapper
int CHACHAXOR_FUNC(uint8_t *output, const uint8_t *input, uint64_t input_length, const uint8_t *nonce, const uint8_t *key) {
  jade_stream_chacha_chacha20_amd64_avx_xor_perso(output, input, input_length, nonce, key);
  return 0;
}

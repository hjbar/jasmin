#define SHA_FUNC jade_stream_chacha_chacha20_amd64_avx_xor
#include "../../utils/chacha20xor_shared.h"
#include <sodium.h>
#include <stdint.h>
#include <stddef.h>


// Hack sodium to choose the sse version of chacha20xor
/*
int sodium_runtime_has_neon() {
  return 0;
}
*/

/*
int sodium_runtime_has_armcrypto() {
  return 0;
}
*/

/*
int sodium_runtime_has_sse2() {
  return 0;
}
*/

/*
int sodium_runtime_has_sse3() {
  return 0;
}
*/

/*
int sodium_runtime_has_ssse3() {
  return 0;
}
*/

/*
int sodium_runtime_has_sse41() {
  return 0;
}
*/

int sodium_runtime_has_avx() {
  return 0;
}

int sodium_runtime_has_avx2() {
  return 0;
}

int sodium_runtime_has_avx512f() {
  return 0;
}

/*
int sodium_runtime_has_pclmul() {
  return 0;
}
*/

/*
int sodium_runtime_has_aesni() {
  return 0;
}
*/

/*
int sodium_runtime_has_rdrand() {
  return 0;
}
*/


// Declare the libsodium wrapper
int CHACHAXOR_FUNC(uint8_t *output, const uint8_t *input, uint64_t input_length, const uint8_t *nonce, const uint8_t *key) {
  if (sodium_init() < 0) {
    return -1;
  }

  crypto_stream_chacha20_xor(output, input, input_length, nonce, key);

  return 0;
}

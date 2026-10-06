#define SHA_FUNC jade_hash_sha256_amd64_ref
#include "../../utils/sha256_shared.h"
#include <sodium.h>
#include <stdint.h>
#include <stddef.h>


// Hack sodium to choose the reference version of sha256
int sodium_runtime_has_neon() {
  return 0;
}

/*
int sodium_runtime_has_armcrypto() {
  return 0;
}
*/

int sodium_runtime_has_sse2() {
  return 0;
}

int sodium_runtime_has_sse3() {
  return 0;
}

int sodium_runtime_has_ssse3() {
  return 0;
}

int sodium_runtime_has_sse41() {
  return 0;
}

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
int SHA_FUNC(uint8_t *hash, const uint8_t *input, uint64_t input_length) {
  if (sodium_init() < 0) {
    return 1;
  }

  crypto_hash_sha256(hash, input, input_length);

  return 0;
}

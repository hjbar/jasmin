#define SHA_FUNC jade_hash_sha256_amd64_ref
#include "../../utils/sha256_shared.h"
#include "../../libjade_c/sha256/sha256_ref.c"
#include <stdint.h>
#include <stddef.h>


// Declare the libsodium wrapper
int SHA_FUNC(uint8_t *hash, const uint8_t *input, uint64_t input_length) {
  jade_hash_sha256_amd64_ref_perso(hash, input, input_length);
  return 0;
}

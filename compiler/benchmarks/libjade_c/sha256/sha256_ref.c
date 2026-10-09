#include <stdint.h>
#include "sha256_core_ref.h"

uint64_t jade_hash_sha256_amd64_ref_perso(uint8_t *hash, const uint8_t *input, uint64_t input_length)
{
  __sha256_ref(hash, input, input_length);
  return 0;
}

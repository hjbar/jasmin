#include <stdint.h>

#ifndef CHACHA_ROUNDS
#define CHACHA_ROUNDS 20
#endif

#include "chacha_ref.h"

uint64_t jade_stream_chacha_chacha20_amd64_ref_perso(
    uint8_t *stream,
    uint64_t stream_length,
    const uint8_t *nonce,
    const uint8_t *key
) {
    __chacha_ref(stream, stream_length, nonce, key);
    return 0;
}

uint64_t jade_stream_chacha_chacha20_amd64_ref_xor_perso(
    uint8_t *output,
    const uint8_t *input,
    uint64_t len,
    const uint8_t *nonce,
    const uint8_t *key)
{
    __chacha_xor_ref(output, input, len, nonce, key);
    return 0;
}

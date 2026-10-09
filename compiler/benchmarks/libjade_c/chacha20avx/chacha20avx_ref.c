#include <stdint.h>
#include <stddef.h>
#include <immintrin.h>

#include "_chacha_avx_ref.h"

#define CHACHA_ROUNDS 20

uint64_t jade_stream_chacha_chacha20_amd64_avx_perso(
    uint8_t *stream,
    uint64_t stream_length,
    const uint8_t *nonce,
    const uint8_t *key)
{
    __chacha_avx(stream, stream_length, nonce, key);

    uint64_t r = 0;
    return r;
}

uint64_t jade_stream_chacha_chacha20_amd64_avx_xor_perso(
    uint8_t *output,
    const uint8_t *input,
    uint64_t len,
    const uint8_t *nonce,
    const uint8_t *key)
{
    __chacha_xor_avx(output, input, len, nonce, key);

    uint64_t r = 0;
    return r;
}

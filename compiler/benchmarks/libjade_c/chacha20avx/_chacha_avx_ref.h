#ifndef CHACHA_AVX_REF_H
#define CHACHA_AVX_REF_H

#include <stdint.h>
#include <stddef.h>

#include "chacha_entry_h_avx_ref.h"
#include "chacha_entry_v_avx_ref.h"

static inline void __chacha_xor_avx(
    uint8_t *output,
    const uint8_t *input,
    uint64_t len,
    const uint8_t *nonce,
    const uint8_t *key)
{
    if (len < 129) {
        __chacha_xor_h_x2_avx(output, input, len, nonce, key);
    } else {
        __chacha_xor_v_avx(output, input, len, nonce, key);
    }
}

static inline void __chacha_avx(
    uint8_t *output,
    uint64_t len,
    const uint8_t *nonce,
    const uint8_t *key)
{
    if (len < 129) {
        __chacha_h_x2_avx(output, len, nonce, key);
    } else {
        __chacha_v_avx(output, len, nonce, key);
    }
}

#endif

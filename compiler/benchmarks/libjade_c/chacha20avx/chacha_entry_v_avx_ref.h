#ifndef CHACHA_ENTRY_V_AVX_REF_H
#define CHACHA_ENTRY_V_AVX_REF_H

#include "chacha_state_v_avx_ref.h"
#include "chacha_core_v_avx_ref.h"
#include "chacha_store_v_avx_ref.h"

void __store_xor_last_v_avx(uint8_t *output, const uint8_t *input, uint64_t len, const __m128i k[16]);
void __store_last_v_avx(uint8_t *output, uint64_t len, const __m128i k[16]);

static inline void __chacha_xor_v_avx(
    uint8_t *output,
    const uint8_t *input,
    uint64_t len,
    const uint8_t *nonce,
    const uint8_t *key)
{
    __m128i st[16];
    __m128i k[16];
    __m128i r16 = CHACHA_R16_AVX;
    __m128i r8  = CHACHA_R8_AVX;

    __init_v_avx(st, nonce, key);

    while (len >= 256) {
        for (int i = 0; i < 16; i++) k[i] = st[i];
        __rounds_v_avx(k, r16, r8);
        __sum_states_v_avx(k, st);
        __store_xor_v_avx(&output, &input, &len, k);
        __increment_counter_v_avx(st);
    }

    if (len > 0) {
        for (int i = 0; i < 16; i++) k[i] = st[i];
        __rounds_v_avx(k, r16, r8);
        __sum_states_v_avx(k, st);
        __store_xor_last_v_avx(output, input, len, k);
    }
}

static inline void __chacha_v_avx(
    uint8_t *output,
    uint64_t len,
    const uint8_t *nonce,
    const uint8_t *key)
{
    __m128i st[16];
    __m128i k[16];
    __m128i r16 = CHACHA_R16_AVX;
    __m128i r8  = CHACHA_R8_AVX;

    __init_v_avx(st, nonce, key);

    while (len >= 256) {
        for (int i = 0; i < 16; i++) k[i] = st[i];
        __rounds_v_avx(k, r16, r8);
        __sum_states_v_avx(k, st);
        __store_v_avx(&output, &len, k);
        __increment_counter_v_avx(st);
    }

    if (len > 0) {
        for (int i = 0; i < 16; i++) k[i] = st[i];
        __rounds_v_avx(k, r16, r8);
        __sum_states_v_avx(k, st);
        __store_last_v_avx(output, len, k);
    }
}

#endif

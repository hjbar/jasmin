#ifndef CHACHA_ENTRY_H_AVX_REF_H
#define CHACHA_ENTRY_H_AVX_REF_H

#include "chacha_core_h_avx_ref.h"
#include "chacha_store_h_avx_ref.h"

static inline void __chacha_xor_h_avx(uint8_t *out, const uint8_t *in, uint64_t len, const uint8_t *nonce, const uint8_t *key) {
    __m128i st[4], k[4];
    __m128i r16 = _mm_setr_epi8(2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13);
    __m128i r8  = _mm_setr_epi8(3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14);

    __init_h_avx(st, nonce, key);

    while (len >= 64) {
        __copy_state_h_avx(k, st);
        __rounds_h_avx(k, r16, r8);
        __sum_states_h_avx(k, st);
        __store_xor_h_avx(&out, &in, &len, k);
        __increment_counter01_h_avx(st);
    }

    if (len > 0) {
        __copy_state_h_avx(k, st);
        __rounds_h_avx(k, r16, r8);
        __sum_states_h_avx(k, st);
        __store_xor_last_h_avx(out, in, len, k);
    }
}

static inline void __chacha_xor_h_x2_avx(uint8_t *out, const uint8_t *in, uint64_t len, const uint8_t *nonce, const uint8_t *key) {
    __m128i st[4], k1[4], k2[4];
    __m128i r16 = _mm_setr_epi8(2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13);
    __m128i r8  = _mm_setr_epi8(3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14);

    __init_h_avx(st, nonce, key);

    while (len >= 128) {
        __copy_state_h_x2_avx(k1, k2, st);
        __rounds_h_x2_avx(k1, k2, r16, r8);
        __sum_states_h_x2_avx(k1, k2, st);
        __store_xor_h_x2_avx(&out, &in, &len, k1, k2);
        __increment_counter02_h_avx(st);
    }

    if (len > 64) {
        __copy_state_h_x2_avx(k1, k2, st);
        __rounds_h_x2_avx(k1, k2, r16, r8);
        __sum_states_h_x2_avx(k1, k2, st);
        __store_xor_h_avx(&out, &in, &len, k1);
        __store_xor_last_h_avx(out, in, len, k2);
    } else if (len > 0) {
        __copy_state_h_avx(k1, st);
        __rounds_h_avx(k1, r16, r8);
        __sum_states_h_avx(k1, st);
        __store_xor_last_h_avx(out, in, len, k1);
    }
}

static inline void __chacha_h_avx(
    uint8_t *out,
    uint64_t len,
    const uint8_t *nonce,
    const uint8_t *key)
{
    __m128i st[4], k[4];
    __m128i r16 = _mm_setr_epi8(2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13);
    __m128i r8  = _mm_setr_epi8(3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14);

    __init_h_avx(st, nonce, key);

    while (len >= 64) {
        __copy_state_h_avx(k, st);
        __rounds_h_avx(k, r16, r8);
        __sum_states_h_avx(k, st);
        __store_h_avx(&out, &len, k);
        __increment_counter01_h_avx(st);
    }

    if (len > 0) {
        __copy_state_h_avx(k, st);
        __rounds_h_avx(k, r16, r8);
        __sum_states_h_avx(k, st);
        __store_last_h_avx(out, len, k);
    }
}

static inline void __chacha_h_x2_avx(
    uint8_t *out,
    uint64_t len,
    const uint8_t *nonce,
    const uint8_t *key)
{
    __m128i st[4], k1[4], k2[4];
    __m128i r16 = _mm_setr_epi8(2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13);
    __m128i r8  = _mm_setr_epi8(3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14);

    __init_h_avx(st, nonce, key);

    while (len >= 128) {
        __copy_state_h_x2_avx(k1, k2, st);
        __rounds_h_x2_avx(k1, k2, r16, r8);
        __sum_states_h_x2_avx(k1, k2, st);
        __store_h_x2_avx(&out, &len, k1, k2);
        __increment_counter02_h_avx(st);
    }

    if (len > 64) {
        __copy_state_h_x2_avx(k1, k2, st);
        __rounds_h_x2_avx(k1, k2, r16, r8);
        __sum_states_h_x2_avx(k1, k2, st);
        __store_h_avx(&out, &len, k1);
        __store_last_h_avx(out, len, k2);
    } else if (len > 0) {
        __copy_state_h_avx(k1, st);
        __rounds_h_avx(k1, r16, r8);
        __sum_states_h_avx(k1, st);
        __store_last_h_avx(out, len, k1);
    }
}

#endif

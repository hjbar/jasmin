#ifndef CHACHA_CORE_V_AVX_REF_H
#define CHACHA_CORE_V_AVX_REF_H

#include <immintrin.h>
#include "chacha_state_v_avx_ref.h"

#define CHACHA_ROUNDS 20

static inline void __rotate_v_avx(__m128i k[16], int i, int r, __m128i r16, __m128i r8)
{
    if (r == 16) {
        k[i] = _mm_shuffle_epi8(k[i], r16);
    } else if (r == 8) {
        k[i] = _mm_shuffle_epi8(k[i], r8);
    } else {
        __m128i t = _mm_slli_epi32(k[i], r);
        k[i] = _mm_srli_epi32(k[i], 32 - r);
        k[i] = _mm_xor_si128(k[i], t);
    }
}

static inline void __line_v_avx(__m128i k[16], int a, int b, int c, int r, __m128i r16, __m128i r8)
{
    k[a] = _mm_add_epi32(k[a], k[b]);
    k[c] = _mm_xor_si128(k[c], k[a]);
    __rotate_v_avx(k, c, r, r16, r8);
}

static inline void __quarter_round_v_avx(__m128i k[16], int a, int b, int c, int d, __m128i r16, __m128i r8)
{
    __line_v_avx(k, a, b, d, 16, r16, r8);
    __line_v_avx(k, c, d, b, 12, r16, r8);
    __line_v_avx(k, a, b, d, 8,  r16, r8);
    __line_v_avx(k, c, d, b, 7,  r16, r8);
}

static inline void __double_round_v_avx(__m128i k[16], __m128i r16, __m128i r8)
{
    __quarter_round_v_avx(k, 0, 4,  8, 12, r16, r8);
    __quarter_round_v_avx(k, 1, 5,  9, 13, r16, r8);
    __quarter_round_v_avx(k, 2, 6, 10, 14, r16, r8);
    __quarter_round_v_avx(k, 3, 7, 11, 15, r16, r8);

    __quarter_round_v_avx(k, 0, 5, 10, 15, r16, r8);
    __quarter_round_v_avx(k, 1, 6, 11, 12, r16, r8);
    __quarter_round_v_avx(k, 2, 7, 8,  13, r16, r8);
    __quarter_round_v_avx(k, 3, 4, 9,  14, r16, r8);
}

static inline void __rounds_v_avx(__m128i k[16], __m128i r16, __m128i r8)
{
    for (int c = CHACHA_ROUNDS / 2; c > 0; c--) {
        __double_round_v_avx(k, r16, r8);
    }
}

static inline void __sum_states_v_avx(__m128i k[16], const __m128i st[16])
{
    for (int i = 0; i < 16; i++) {
        k[i] = _mm_add_epi32(k[i], st[i]);
    }
}

#endif

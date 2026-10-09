#ifndef CHACHA_CORE_H_AVX_REF_H
#define CHACHA_CORE_H_AVX_REF_H

#include "chacha_state_h_avx_ref.h"

#define CHACHA_ROUNDS 20

static inline void __copy_state_h_avx(__m128i dst[4], const __m128i src[4]) {
    for (int i = 0; i < 4; i++) dst[i] = src[i];
}

static inline __m128i __rotate_word(__m128i val, int r, __m128i r16, __m128i r8) {
    if (r == 16) return _mm_shuffle_epi8(val, r16);
    if (r == 8)  return _mm_shuffle_epi8(val, r8);
    __m128i t = _mm_slli_epi32(val, r);
    return _mm_xor_si128(_mm_srli_epi32(val, 32 - r), t);
}

static inline void __line_h_avx(__m128i k[4], int a, int b, int c, int r, __m128i r16, __m128i r8) {
    k[a] = _mm_add_epi32(k[a], k[b]);
    k[c] = _mm_xor_si128(k[c], k[a]);
    k[c] = __rotate_word(k[c], r, r16, r8);
}

static inline void __round_h_avx(__m128i k[4], __m128i r16, __m128i r8) {
    __line_h_avx(k, 0, 1, 3, 16, r16, r8);
    __line_h_avx(k, 2, 3, 1, 12, r16, r8);
    __line_h_avx(k, 0, 1, 3,  8, r16, r8);
    __line_h_avx(k, 2, 3, 1,  7, r16, r8);
}

static inline void __shuffle_state_h_avx(__m128i k[4]) {
    k[1] = _mm_shuffle_epi32(k[1], _MM_SHUFFLE(0, 3, 2, 1));
    k[2] = _mm_shuffle_epi32(k[2], _MM_SHUFFLE(1, 0, 3, 2));
    k[3] = _mm_shuffle_epi32(k[3], _MM_SHUFFLE(2, 1, 0, 3));
}

static inline void __reverse_shuffle_state_h_avx(__m128i k[4]) {
    k[1] = _mm_shuffle_epi32(k[1], _MM_SHUFFLE(2, 1, 0, 3));
    k[2] = _mm_shuffle_epi32(k[2], _MM_SHUFFLE(1, 0, 3, 2));
    k[3] = _mm_shuffle_epi32(k[3], _MM_SHUFFLE(0, 3, 2, 1));
}

static inline void __double_round_h_avx(__m128i k[4], __m128i r16, __m128i r8) {
    __round_h_avx(k, r16, r8);
    __shuffle_state_h_avx(k);
    __round_h_avx(k, r16, r8);
    __reverse_shuffle_state_h_avx(k);
}

static inline void __rounds_h_avx(__m128i k[4], __m128i r16, __m128i r8) {
    for (int c = CHACHA_ROUNDS / 2; c > 0; c--) {
        __double_round_h_avx(k, r16, r8);
    }
}

static inline void __sum_states_h_avx(__m128i k[4], const __m128i st[4]) {
    for (int i = 0; i < 4; i++) {
        k[i] = _mm_add_epi32(k[i], st[i]);
    }
}

static inline void __copy_state_h_x2_avx(__m128i k1[4], __m128i k2[4], const __m128i st[4]) {
    __copy_state_h_avx(k1, st);
    __copy_state_h_avx(k2, st);
    __increment_counter01_h_avx(k2);
}

static inline void __double_round_h_x2_avx(__m128i k1[4], __m128i k2[4], __m128i r16, __m128i r8) {
    __double_round_h_avx(k1, r16, r8);
    __double_round_h_avx(k2, r16, r8);
}

static inline void __rounds_h_x2_avx(__m128i k1[4], __m128i k2[4], __m128i r16, __m128i r8) {
    for (int c = CHACHA_ROUNDS / 2; c > 0; c--) {
        __double_round_h_x2_avx(k1, k2, r16, r8);
    }
}

static inline void __sum_states_h_x2_avx(__m128i k1[4], __m128i k2[4], const __m128i st[4]) {
    __sum_states_h_avx(k1, st);
    __sum_states_h_avx(k2, st);
    __increment_counter01_h_avx(k2);
}

#endif

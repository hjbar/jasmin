#ifndef CHACHA_STATE_H_AVX_REF_H
#define CHACHA_STATE_H_AVX_REF_H

#include <immintrin.h>
#include <stdint.h>

static const uint32_t CHACHA_SIGMA[4] = {0x61707865, 0x3320646e, 0x79622d32, 0x6b206574};

static inline void __init_h_avx(__m128i st[4], const uint8_t *nonce, const uint8_t *key) {
    st[0] = _mm_loadu_si128((const __m128i*)CHACHA_SIGMA);
    st[1] = _mm_loadu_si128((const __m128i*)(key + 0));
    st[2] = _mm_loadu_si128((const __m128i*)(key + 16));

    uint64_t n0 = *(const uint64_t*)nonce;
    st[3] = _mm_set_epi64x((int64_t)n0, 0);
}

static inline void __increment_counter01_h_avx(__m128i st[4]) {
    __m128i p01 = _mm_set_epi64x(0, 1);
    st[3] = _mm_add_epi64(st[3], p01);
}

static inline void __increment_counter02_h_avx(__m128i st[4]) {
    __m128i p02 = _mm_set_epi64x(0, 2);
    st[3] = _mm_add_epi64(st[3], p02);
}

#endif

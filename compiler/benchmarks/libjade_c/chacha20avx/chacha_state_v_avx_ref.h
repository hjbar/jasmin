#ifndef CHACHA_STATE_V_AVX_REF_H
#define CHACHA_STATE_V_AVX_REF_H

#include <stdint.h>
#include <immintrin.h>

#define CHACHA_R16_AVX _mm_set_epi8(13, 12, 15, 14, 9, 8, 11, 10, 5, 4, 7, 6, 1, 0, 3, 2)
#define CHACHA_R8_AVX  _mm_set_epi8(14, 13, 12, 15, 10, 9, 8, 11, 6, 5, 4, 7, 2, 1, 0, 3)

static inline void __init_v_avx(__m128i st[16], const uint8_t *nonce, const uint8_t *key)
{
    st[0] = _mm_set1_epi32(0x61707865);
    st[1] = _mm_set1_epi32(0x3320646e);
    st[2] = _mm_set1_epi32(0x79622d32);
    st[3] = _mm_set1_epi32(0x6b206574);

    const uint32_t *k32 = (const uint32_t *)key;
    for (int i = 0; i < 8; i++) {
        st[4 + i] = _mm_set1_epi32(k32[i]);
    }

    st[12] = _mm_set_epi32(3, 2, 1, 0);
    st[13] = _mm_setzero_si128();

    const uint32_t *n32 = (const uint32_t *)nonce;
    st[14] = _mm_set1_epi32(n32[0]);
    st[15] = _mm_set1_epi32(n32[1]);
}

static inline void __increment_counter_v_avx(__m128i st[16])
{
    __m128i x = st[12];
    __m128i y = st[13];

    __m128i a = _mm_unpacklo_epi32(x, y);
    __m128i b = _mm_unpackhi_epi32(x, y);

    __m128i p44 = _mm_set_epi64x(4, 4);
    a = _mm_add_epi64(a, p44);
    b = _mm_add_epi64(b, p44);

    x = _mm_unpacklo_epi32(a, b);
    y = _mm_unpackhi_epi32(a, b);

    st[12] = _mm_unpacklo_epi32(x, y);
    st[13] = _mm_unpackhi_epi32(x, y);
}

#endif

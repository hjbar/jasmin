#ifndef CHACHA_STORE_V_AVX_REF_H
#define CHACHA_STORE_V_AVX_REF_H

#include <stdint.h>
#include <immintrin.h>
#include <string.h>

static inline void __sub_rotate_avx(const __m128i t[8], __m128i x[8])
{
    x[0] = _mm_unpacklo_epi64(t[0], t[1]);
    x[1] = _mm_unpacklo_epi64(t[2], t[3]);
    x[2] = _mm_unpackhi_epi64(t[0], t[1]);
    x[3] = _mm_unpackhi_epi64(t[2], t[3]);

    x[4] = _mm_unpacklo_epi64(t[4], t[5]);
    x[5] = _mm_unpacklo_epi64(t[6], t[7]);
    x[6] = _mm_unpackhi_epi64(t[4], t[5]);
    x[7] = _mm_unpackhi_epi64(t[6], t[7]);
}

static inline void __rotate_avx(const __m128i input[8], __m128i output[8])
{
    __m128i t[8];
    for (int i = 0; i < 4; i++) {
        t[i]     = _mm_unpacklo_epi32(input[2 * i], input[2 * i + 1]);
        t[4 + i] = _mm_unpackhi_epi32(input[2 * i], input[2 * i + 1]);
    }
    __sub_rotate_avx(t, output);
}

static inline void __store_xor_half_interleave_v_avx(
    uint8_t *output,
    const uint8_t *input,
    __m128i k[8],
    int offset)
{
    for (int i = 0; i < 4; i++) {
        __m128i in0 = _mm_loadu_si128((const __m128i *)(input + offset + 64 * i));
        __m128i in1 = _mm_loadu_si128((const __m128i *)(input + offset + 64 * i + 16));

        k[2 * i]     = _mm_xor_si128(k[2 * i], in0);
        k[2 * i + 1] = _mm_xor_si128(k[2 * i + 1], in1);

        _mm_storeu_si128((__m128i *)(output + offset + 64 * i),      k[2 * i]);
        _mm_storeu_si128((__m128i *)(output + offset + 64 * i + 16), k[2 * i + 1]);
    }
}

static inline void __store_xor_v_avx(
    uint8_t **output,
    const uint8_t **input,
    uint64_t *len,
    const __m128i k[16])
{
    __m128i k0_7[8], k8_15[8];

    __rotate_avx(&k[0], k0_7);
    __store_xor_half_interleave_v_avx(*output, *input, k0_7, 0);

    __rotate_avx(&k[8], k8_15);
    __store_xor_half_interleave_v_avx(*output, *input, k8_15, 32);

    *output += 256;
    *input  += 256;
    *len    -= 256;
}

static inline void __store_half_interleave_v_avx(
    uint8_t *output,
    __m128i k[8],
    int offset)
{
    for (int i = 0; i < 4; i++) {
        _mm_storeu_si128((__m128i *)(output + offset + 64 * i),      k[2 * i]);
        _mm_storeu_si128((__m128i *)(output + offset + 64 * i + 16), k[2 * i + 1]);
    }
}

static inline void __store_v_avx(
    uint8_t **output,
    uint64_t *len,
    const __m128i k[16])
{
    __m128i k0_7[8], k8_15[8];

    __rotate_avx(&k[0], k0_7);
    __store_half_interleave_v_avx(*output, k0_7, 0);

    __rotate_avx(&k[8], k8_15);
    __store_half_interleave_v_avx(*output, k8_15, 32);

    *output += 256;
    *len    -= 256;
}

static inline void __store_last_v_avx(
    uint8_t *output,
    uint64_t len,
    const __m128i k[16])
{
    uint8_t buf[256];
    uint8_t *pbuf = buf;
    uint64_t tmp_len = 256;
    __store_v_avx(&pbuf, &tmp_len, k);
    memcpy(output, buf, len);
}

static inline void __store_xor_last_v_avx(
    uint8_t *output,
    const uint8_t *input,
    uint64_t len,
    const __m128i k[16])
{
    uint8_t buf[256];
    uint8_t *pbuf = buf;
    uint64_t tmp_len = 256;
    __store_v_avx(&pbuf, &tmp_len, k);
    for (uint64_t i = 0; i < len; i++) {
        output[i] = input[i] ^ buf[i];
    }
}

#endif

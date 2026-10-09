#ifndef CHACHA_STORE_H_AVX_REF_H
#define CHACHA_STORE_H_AVX_REF_H

#include <immintrin.h>
#include <stdint.h>

static inline uint64_t __extract_epi64_0(__m128i v) {
    uint64_t r;
    _mm_storel_epi64((__m128i*)&r, v);
    return r;
}

static inline uint64_t __extract_epi64_1(__m128i v) {
    uint64_t r;
    _mm_storel_epi64((__m128i*)&r, _mm_srli_si128(v, 8));
    return r;
}

static inline void __store_xor_h_avx(uint8_t **out, const uint8_t **in, uint64_t *len, __m128i k[4]) {
    for (int i = 0; i < 4; i++) {
        __m128i in_v = _mm_loadu_si128((const __m128i*)(*in + 16 * i));
        __m128i res = _mm_xor_si128(k[i], in_v);
        _mm_storeu_si128((__m128i*)(*out + 16 * i), res);
    }
    *out += 64; *in += 64; *len -= 64;
}

static inline void __store_xor_last_h_avx(uint8_t *out, const uint8_t *in, uint64_t len, __m128i k[4]) {
    if (len >= 32) {
        for (int i = 0; i < 2; i++) {
            __m128i in_v = _mm_loadu_si128((const __m128i*)(in + 16 * i));
            _mm_storeu_si128((__m128i*)(out + 16 * i), _mm_xor_si128(k[i], in_v));
        }
        out += 32; in += 32; len -= 32;
        k[0] = k[2]; k[1] = k[3];
    }
    if (len >= 16) {
        __m128i in_v = _mm_loadu_si128((const __m128i*)in);
        _mm_storeu_si128((__m128i*)out, _mm_xor_si128(k[0], in_v));
        out += 16; in += 16; len -= 16;
        k[0] = k[1];
    }
    uint64_t r0 = __extract_epi64_0(k[0]);
    if (len >= 8) {
        uint64_t in64 = *(const uint64_t*)in;
        *(uint64_t*)out = r0 ^ in64;
        out += 8; in += 8; len -= 8;
        r0 = __extract_epi64_1(k[0]);
    }
    while (len > 0) {
        uint8_t r1 = (uint8_t)r0;
        *out = r1 ^ (*in);
        r0 >>= 8; out++; in++; len--;
    }
}

static inline void __store_h_avx(uint8_t **out, uint64_t *len, __m128i k[4]) {
    for (int i = 0; i < 4; i++) {
        _mm_storeu_si128((__m128i*)(*out + 16 * i), k[i]);
    }
    *out += 64;
    *len -= 64;
}

static inline void __store_last_h_avx(uint8_t *out, uint64_t len, __m128i k[4]) {
    if (len >= 32) {
        for (int i = 0; i < 2; i++) {
            _mm_storeu_si128((__m128i*)(out + 16 * i), k[i]);
        }
        out += 32; len -= 32;
        k[0] = k[2]; k[1] = k[3];
    }
    if (len >= 16) {
        _mm_storeu_si128((__m128i*)out, k[0]);
        out += 16; len -= 16;
        k[0] = k[1];
    }
    uint64_t r0 = __extract_epi64_0(k[0]);
    if (len >= 8) {
        *(uint64_t*)out = r0;
        out += 8; len -= 8;
        r0 = __extract_epi64_1(k[0]);
    }
    while (len > 0) {
        *out = (uint8_t)r0;
        r0 >>= 8; out++; len--;
    }
}

static inline void __store_xor_h_x2_avx(uint8_t **out, const uint8_t **in, uint64_t *len, __m128i k1[4], __m128i k2[4]) {
    __store_xor_h_avx(out, in, len, k1);
    __store_xor_h_avx(out, in, len, k2);
}

static inline void __store_xor_last_h_x2_avx(uint8_t *out, const uint8_t *in, uint64_t len, __m128i k1[4], __m128i k2[4]) {
    if (len >= 64) {
        __store_xor_h_avx(&out, &in, &len, k1);
        k1[0] = k2[0]; k1[1] = k2[1]; k1[2] = k2[2]; k1[3] = k2[3];
    }
    __store_xor_last_h_avx(out, in, len, k1);
}

static inline void __store_h_x2_avx(uint8_t **out, uint64_t *len, __m128i k1[4], __m128i k2[4]) {
    __store_h_avx(out, len, k1);
    __store_h_avx(out, len, k2);
}

#endif

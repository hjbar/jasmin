#ifndef CHACHA_CORE_REF_H
#define CHACHA_CORE_REF_H

#include <stdint.h>
#include "chacha_state_ref.h"

#ifndef CHACHA_ROUNDS
#define CHACHA_ROUNDS 20
#endif

static inline uint32_t ROL_32(uint32_t x, int r) {
#if defined(__clang__) && __has_builtin(__builtin_rotateleft32)
    return __builtin_rotateleft32(x, r);
#elif defined(_MSC_VER)
    #include <stdlib.h>
    return _rotl(x, r);
#else
    return (x << r) | (x >> (32 - r));
#endif
}

static inline void __copy_state_ref(uint32_t k[16], uint32_t *s_k15, const uint32_t st[16]) {
    uint32_t k15 = st[15];
    *s_k15 = k15;

    for (int i = 0; i < 16; i++) {
        k[i] = st[i];
    }
}

static inline void __line_ref(uint32_t k[16], int a, int b, int c, int r) {
    k[a] += k[b];
    k[c] ^= k[a];
    k[c] = ROL_32(k[c], r);
}

static inline void __quarter_round_ref(uint32_t k[16], int a, int b, int c, int d) {
    __line_ref(k, a, b, d, 16);
    __line_ref(k, c, d, b, 12);
    __line_ref(k, a, b, d, 8);
    __line_ref(k, c, d, b, 7);
}

static inline void __column_round_ref(uint32_t k[16], uint32_t *k15) {
    uint32_t k14;

    __quarter_round_ref(k, 0, 4, 8, 12);
    __quarter_round_ref(k, 1, 5, 9, 13);

    __quarter_round_ref(k, 2, 6, 10, 14);
    k14 = k[14]; k[15] = *k15;

    __quarter_round_ref(k, 3, 7, 11, 15);
    *k15 = k[15]; k[14] = k14;
}

static inline void __diagonal_round_ref(uint32_t k[16], uint32_t *k15) {
    uint32_t k14 = k[14];
    k[15] = *k15;

    __quarter_round_ref(k, 0, 5, 10, 15);
    *k15 = k[15]; k[14] = k14;

    __quarter_round_ref(k, 1, 6, 11, 12);
    __quarter_round_ref(k, 2, 7, 8, 13);
    __quarter_round_ref(k, 3, 4, 9, 14);
}

static inline void __double_round_ref(uint32_t k[16], uint32_t *k15) {
    __column_round_ref(k, k15);
    __diagonal_round_ref(k, k15);
}

static inline void __rounds_ref(uint32_t k[16], uint32_t *k15) {
    uint32_t c = CHACHA_ROUNDS / 2;
    while (c > 0) {
        __double_round_ref(k, k15);
        c--;
    }
}

static inline void __half_round_inline_ref(
    uint32_t k[16],
    int a0, int b0, int c0, int d0,
    int a1, int b1, int c1, int d1
) {
    k[a0] += k[b0];
    k[a1] += k[b1];

    k[d0] ^= k[a0];
    k[d1] ^= k[a1];

    k[d0] = ROL_32(k[d0], 16);
    k[d1] = ROL_32(k[d1], 16);

    k[c0] += k[d0];
    k[c1] += k[d1];

    k[b0] ^= k[c0];
    k[b1] ^= k[c1];

    k[b0] = ROL_32(k[b0], 12);
    k[b1] = ROL_32(k[b1], 12);

    k[a0] += k[b0];
    k[a1] += k[b1];

    k[d0] ^= k[a0];
    k[d1] ^= k[a1];

    k[d0] = ROL_32(k[d0], 8);
    k[d1] = ROL_32(k[d1], 8);

    k[c0] += k[d0];
    k[c1] += k[d1];

    k[b0] ^= k[c0];
    k[b1] ^= k[c1];

    k[b0] = ROL_32(k[b0], 7);
    k[b1] = ROL_32(k[b1], 7);
}

static inline void __double_round_inline_ref(uint32_t k[16], uint32_t *k14, uint32_t *k15) {
    k[14] = *k14;

    __half_round_inline_ref(k, 0, 4, 8, 12,
                               2, 6, 10, 14);
    *k14 = k[14];
    k[15] = *k15;

    __half_round_inline_ref(k, 1, 5, 9, 13,
                               3, 7, 11, 15);

    __half_round_inline_ref(k, 1, 6, 11, 12,
                               0, 5, 10, 15);

    *k15 = k[15];
    k[14] = *k14;

    __half_round_inline_ref(k, 2, 7, 8, 13,
                               3, 4, 9, 14);

    *k14 = k[14];
}

static inline void __rounds_inline_ref(uint32_t k[16], uint32_t *k15) {
    uint32_t k14 = k[14];
    uint32_t c = CHACHA_ROUNDS / 2;

    while (c > 0) {
        uint32_t s_c = c;

        __double_round_inline_ref(k, &k14, k15);

        c = s_c - 1;
    }

    k[14] = k14;
}

static inline void __sum_states_ref(uint32_t k[16], uint32_t *k15, const uint32_t st[16]) {
    for (int i = 0; i < 16; i++) {
        k[i] += st[i];
    }

    uint32_t k14 = k[14];

    uint32_t t = *k15;
    t += st[15];
    *k15 = t;

    k[14] = k14;
}

#endif

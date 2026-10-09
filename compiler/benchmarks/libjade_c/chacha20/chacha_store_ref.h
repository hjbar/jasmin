#ifndef CHACHA_STORE_REF_H
#define CHACHA_STORE_REF_H

#include <stdint.h>
#include "chacha_state_ref.h"

static inline void __update_ptr_xor_ref(uint8_t **output, const uint8_t **input, uint64_t *len, int n) {
    *output += n;
    *input += n;
    *len -= n;
}

static inline void __store_xor_ref(
    uint8_t **s_output, const uint8_t **s_input, uint64_t *s_len,
    const uint32_t k[16], uint32_t k15
) {
    uint64_t kk[8];
    uint8_t *output;
    const uint8_t *input;
    uint64_t aux, len;

    kk[0] = ((uint64_t)k[1]) << 32;
    aux = (uint64_t)k[0];
    kk[0] ^= aux;
    input = *s_input;
    kk[0] ^= load64_le(input + 8 * 0);

    kk[1] = ((uint64_t)k[3]) << 32;
    aux = (uint64_t)k[2];
    kk[1] ^= aux;
    kk[1] ^= load64_le(input + 8 * 1);
    output = *s_output;
    store64_le(output + 8 * 0, kk[0]);

    for (int i = 2; i < 8; i++) {
        uint32_t ki = (i == 7) ? k15 : k[2 * i + 1];
        kk[i] = ((uint64_t)ki) << 32;
        aux = (uint64_t)k[2 * i];
        kk[i] ^= aux;
        kk[i] ^= load64_le(input + 8 * i);
        store64_le(output + 8 * (i - 1), kk[i - 1]);
    }

    store64_le(output + 8 * 7, kk[7]);

    len = *s_len;
    __update_ptr_xor_ref(&output, &input, &len, 64);

    *s_output = output;
    *s_input = input;
    *s_len = len;
}

static inline void __sum_states_store_xor_ref(
    uint8_t **s_output, const uint8_t **s_input, uint64_t *s_len,
    uint32_t k[16], uint32_t k15,
    const uint32_t st[16]
) {
    uint64_t kk[8];
    uint8_t *output;
    const uint8_t *input;
    uint64_t aux, len;

    k[1] += st[1];
    k[0] += st[0];
    kk[0] = ((uint64_t)k[1]) << 32;
    aux = (uint64_t)k[0];
    kk[0] ^= aux;
    input = *s_input;
    kk[0] ^= load64_le(input + 8 * 0);

    k[3] += st[3];
    k[2] += st[2];
    kk[1] = ((uint64_t)k[3]) << 32;
    aux = (uint64_t)k[2];
    kk[1] ^= aux;
    kk[1] ^= load64_le(input + 8 * 1);
    output = *s_output;
    store64_le(output + 8 * 0, kk[0]);

    for (int i = 2; i < 8; i++) {
        if (2 * i + 1 == 15) { k[2 * i + 1] = k15; }
        k[2 * i + 1] += st[2 * i + 1];
        k[2 * i] += st[2 * i];

        kk[i] = ((uint64_t)k[2 * i + 1]) << 32;
        aux = (uint64_t)k[2 * i];
        kk[i] ^= aux;
        kk[i] ^= load64_le(input + 8 * i);
        store64_le(output + 8 * (i - 1), kk[i - 1]);
    }

    store64_le(output + 8 * 7, kk[7]);

    len = *s_len;
    __update_ptr_xor_ref(&output, &input, &len, 64);

    *s_output = output;
    *s_input = input;
    *s_len = len;
}

static inline void __store_xor_last_ref(
    uint8_t *s_output, const uint8_t *s_input, uint64_t s_len,
    const uint32_t k[16], uint32_t k15
) {
    uint32_t s_k[16];

    for (int i = 0; i < 15; i++) {
        s_k[i] = k[i];
    }
    s_k[15] = k15;

    uint8_t *output = s_output;
    const uint8_t *input = s_input;
    uint64_t len = s_len;

    uint64_t len8 = len >> 3;
    uint64_t j = 0;

    while (j < len8) {
        uint64_t t = load64_le(input + 8 * j);
        uint64_t sk_val = load64_le((const uint8_t *)s_k + 8 * j);
        t ^= sk_val;
        store64_le(output + 8 * j, t);
        j += 1;
    }
    j <<= 3;

    while (j < len) {
        uint8_t pi = input[j];
        pi ^= ((const uint8_t *)s_k)[j];
        output[j] = pi;
        j += 1;
    }
}

static inline void __update_ptr_ref(uint8_t **output, uint64_t *len, int n) {
    *output += n;
    *len -= n;
}

static inline void __store_ref(
    uint8_t **s_output, uint64_t *s_len,
    const uint32_t k[16], uint32_t k15
) {
    uint64_t kk[8];
    uint8_t *output;
    uint64_t aux, len;

    kk[0] = ((uint64_t)k[1]) << 32;
    aux = (uint64_t)k[0];
    kk[0] ^= aux;

    kk[1] = ((uint64_t)k[3]) << 32;
    aux = (uint64_t)k[2];
    kk[1] ^= aux;
    output = *s_output;
    store64_le(output + 8 * 0, kk[0]);

    for (int i = 2; i < 8; i++) {
        uint32_t ki = (i == 7) ? k15 : k[2 * i + 1];
        kk[i] = ((uint64_t)ki) << 32;
        aux = (uint64_t)k[2 * i];
        kk[i] ^= aux;
        store64_le(output + 8 * (i - 1), kk[i - 1]);
    }

    store64_le(output + 8 * 7, kk[7]);

    len = *s_len;
    __update_ptr_ref(&output, &len, 64);

    *s_output = output;
    *s_len = len;
}

static inline void __sum_states_store_ref(
    uint8_t **s_output, uint64_t *s_len,
    uint32_t k[16], uint32_t k15,
    const uint32_t st[16]
) {
    uint64_t kk[8];
    uint8_t *output;
    uint64_t aux, len;

    k[1] += st[1];
    k[0] += st[0];
    kk[0] = ((uint64_t)k[1]) << 32;
    aux = (uint64_t)k[0];
    kk[0] ^= aux;

    k[3] += st[3];
    k[2] += st[2];
    kk[1] = ((uint64_t)k[3]) << 32;
    aux = (uint64_t)k[2];
    kk[1] ^= aux;
    output = *s_output;
    store64_le(output + 8 * 0, kk[0]);

    for (int i = 2; i < 8; i++) {
        if (2 * i + 1 == 15) { k[2 * i + 1] = k15; }
        k[2 * i + 1] += st[2 * i + 1];
        k[2 * i] += st[2 * i];

        kk[i] = ((uint64_t)k[2 * i + 1]) << 32;
        aux = (uint64_t)k[2 * i];
        kk[i] ^= aux;
        store64_le(output + 8 * (i - 1), kk[i - 1]);
    }

    store64_le(output + 8 * 7, kk[7]);

    len = *s_len;
    __update_ptr_ref(&output, &len, 64);

    *s_output = output;
    *s_len = len;
}

static inline void __store_last_ref(
    uint8_t *s_output, uint64_t s_len,
    const uint32_t k[16], uint32_t k15
) {
    uint32_t s_k[16];

    for (int i = 0; i < 15; i++) {
        s_k[i] = k[i];
    }
    s_k[15] = k15;

    uint8_t *output = s_output;
    uint64_t len = s_len;

    uint64_t len8 = len >> 3;
    uint64_t j = 0;

    while (j < len8) {
        uint64_t t = load64_le((const uint8_t *)s_k + 8 * j);
        store64_le(output + 8 * j, t);
        j += 1;
    }
    j <<= 3;

    while (j < len) {
        uint8_t pi = ((const uint8_t *)s_k)[j];
        output[j] = pi;
        j += 1;
    }
}

#endif

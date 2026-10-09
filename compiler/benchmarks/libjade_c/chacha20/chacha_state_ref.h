#ifndef CHACHA_STATE_REF_H
#define CHACHA_STATE_REF_H

#include <stdint.h>
#include <string.h>

static inline uint32_t load32_le(const uint8_t *src) {
    uint32_t w;
    memcpy(&w, src, 4);
    return w;
}

static inline void store32_le(uint8_t *dst, uint32_t w) {
    memcpy(dst, &w, 4);
}

static inline uint64_t load64_le(const uint8_t *src) {
    uint64_t w;
    memcpy(&w, src, 8);
    return w;
}

static inline void store64_le(uint8_t *dst, uint64_t w) {
    memcpy(dst, &w, 8);
}

static inline void __init_ref(uint32_t st[16], const uint8_t *nonce, const uint8_t *key) {
    st[0] = 0x61707865;
    st[1] = 0x3320646e;
    st[2] = 0x79622d32;
    st[3] = 0x6b206574;

    for (int i = 0; i < 8; i++) {
        st[4 + i] = load32_le(key + 4 * i);
    }

    st[12] = 0;
    st[13] = 0;

    for (int i = 0; i < 2; i++) {
        st[14 + i] = load32_le(nonce + 4 * i);
    }
}

static inline void __increment_counter_ref(uint32_t st[16]) {
    uint64_t t = (uint64_t)st[12] | ((uint64_t)st[13] << 32);
    t += 1;
    st[12] = (uint32_t)t;
    st[13] = (uint32_t)(t >> 32);
}

#endif

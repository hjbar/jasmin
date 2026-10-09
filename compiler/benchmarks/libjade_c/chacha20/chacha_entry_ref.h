#ifndef CHACHA_ENTRY_REF_H
#define CHACHA_ENTRY_REF_H

#include <stdint.h>
#include "chacha_state_ref.h"
#include "chacha_core_ref.h"
#include "chacha_store_ref.h"

static inline void __chacha_xor_ref(
    uint8_t *output, const uint8_t *input, uint64_t len,
    const uint8_t *nonce, const uint8_t *key
) {
    uint8_t *s_output = output;
    const uint8_t *s_input = input;
    uint64_t s_len = len;

    uint32_t st[16];
    uint32_t k[16];
    uint32_t k15;

    __init_ref(st, nonce, key);

    while (s_len >= 64) {
        __copy_state_ref(k, &k15, st);
        __rounds_inline_ref(k, &k15);
        __sum_states_store_xor_ref(&s_output, &s_input, &s_len, k, k15, st);
        __increment_counter_ref(st);
    }

    if (s_len > 0) {
        __copy_state_ref(k, &k15, st);
        __rounds_inline_ref(k, &k15);
        __sum_states_ref(k, &k15, st);
        __store_xor_last_ref(s_output, s_input, s_len, k, k15);
    }
}

static inline void __chacha_ref(
    uint8_t *output, uint64_t len,
    const uint8_t *nonce, const uint8_t *key
) {
    uint8_t *s_output = output;
    uint64_t s_len = len;

    uint32_t st[16];
    uint32_t k[16];
    uint32_t k15;

    __init_ref(st, nonce, key);

    while (s_len >= 64) {
        __copy_state_ref(k, &k15, st);
        __rounds_inline_ref(k, &k15);
        __sum_states_store_ref(&s_output, &s_len, k, k15, st);
        __increment_counter_ref(st);
    }

    if (s_len > 0) {
        __copy_state_ref(k, &k15, st);
        __rounds_inline_ref(k, &k15);
        __sum_states_ref(k, &k15, st);
        __store_last_ref(s_output, s_len, k, k15);
    }
}

#endif

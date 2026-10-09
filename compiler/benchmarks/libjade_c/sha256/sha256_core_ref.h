#ifndef SHA256_CORE_REF_H
#define SHA256_CORE_REF_H

#include <stdint.h>
#include <string.h>
#include "sha256_globals_ref.h"

#if defined(_MSC_VER)
  #include <stdlib.h>
  #define BSWAP32(x)   _byteswap_ulong(x)
  #define ROTR32(x, c) _rotr((x), (c))
#else
  #if defined(__GNUC__) || defined(__clang__)
    #define BSWAP32(x) __builtin_bswap32(x)
  #else
    #define BSWAP32(x) ((((uint32_t)(x) & 0xFF000000U) >> 24) | \
                        (((uint32_t)(x) & 0x00FF0000U) >> 8)  | \
                        (((uint32_t)(x) & 0x0000FF00U) << 8)  | \
                        (((uint32_t)(x) & 0x000000FFU) << 24))
  #endif
  #define ROTR32(x, c) (((uint32_t)(x) >> (c)) | ((uint32_t)(x) << (32 - (c))))
#endif

static inline void __initH_ref(uint32_t H[8])
{
  H[0] = 0x6a09e667U;
  H[1] = 0xbb67ae85U;
  H[2] = 0x3c6ef372U;
  H[3] = 0xa54ff53aU;
  H[4] = 0x510e527fU;
  H[5] = 0x9b05688cU;
  H[6] = 0x1f83d9abU;
  H[7] = 0x5be0cd19U;
}

static inline void __load_H_ref(const uint32_t H[8],
                                uint32_t *a, uint32_t *b, uint32_t *c, uint32_t *d,
                                uint32_t *e, uint32_t *f, uint32_t *g, uint32_t *h)
{
  *a = H[0];
  *b = H[1];
  *c = H[2];
  *d = H[3];
  *e = H[4];
  *f = H[5];
  *g = H[6];
  *h = H[7];
}

static inline void __store_H_ref(uint32_t H[8],
                                 uint32_t a, uint32_t b, uint32_t c, uint32_t d,
                                 uint32_t e, uint32_t f, uint32_t g, uint32_t h)
{
  H[0] = a;
  H[1] = b;
  H[2] = c;
  H[3] = d;
  H[4] = e;
  H[5] = f;
  H[6] = g;
  H[7] = h;
}

static inline void __store_ref(uint8_t *out, const uint32_t H[8])
{
  for (int i = 0; i < 8; i++) {
    uint32_t v = BSWAP32(H[i]);
    memcpy(out + i * 4, &v, sizeof(v));
  }
}

static inline uint32_t __SHR_ref(uint32_t x, int c)
{
  return x >> c;
}

static inline uint32_t __ROTR_ref(uint32_t x, int c)
{
  return ROTR32(x, c);
}

static inline uint32_t __CH_ref(uint32_t x, uint32_t y, uint32_t z)
{
  uint32_t r = x & y;
  uint32_t s = (~x) & z;
  return r ^ s;
}

static inline uint32_t __MAJ_ref(uint32_t x, uint32_t y, uint32_t z)
{
  uint32_t r = x & y;
  uint32_t s = x & z;
  r ^= s;
  s = y & z;
  return r ^ s;
}

static inline uint32_t __BSIG0_ref(uint32_t x)
{
  uint32_t r = __ROTR_ref(x, 2);
  uint32_t s = __ROTR_ref(x, 13);
  r ^= s;
  s = __ROTR_ref(x, 22);
  return r ^ s;
}

static inline uint32_t __BSIG1_ref(uint32_t x)
{
  uint32_t r = __ROTR_ref(x, 6);
  uint32_t s = __ROTR_ref(x, 11);
  r ^= s;
  s = __ROTR_ref(x, 25);
  return r ^ s;
}

static inline uint32_t __SSIG0_ref(uint32_t x)
{
  uint32_t r = __ROTR_ref(x, 7);
  uint32_t s = __ROTR_ref(x, 18);
  r ^= s;
  s = __SHR_ref(x, 3);
  return r ^ s;
}

static inline uint32_t __SSIG1_ref(uint32_t x)
{
  uint32_t r = __ROTR_ref(x, 17);
  uint32_t s = __ROTR_ref(x, 19);
  r ^= s;
  s = __SHR_ref(x, 10);
  return r ^ s;
}

static inline void __Wt_ref(uint32_t W[64], int t)
{
  uint32_t wt2  = W[t - 2];
  uint32_t wt   = __SSIG1_ref(wt2);
  wt           += W[t - 7];
  uint32_t wt15 = W[t - 15];
  wt15          = __SSIG0_ref(wt15);
  wt           += wt15;
  wt           += W[t - 16];

  W[t] = wt;
}

static inline void _blocks_0_ref(uint32_t H[8], const uint8_t **in, uint64_t *inlen)
{
  uint32_t W[64];

  while (*inlen >= 64) {
    for (int t = 0; t < 16; t++) {
      uint32_t v;
      memcpy(&v, *in + t * 4, sizeof(v));
      v = BSWAP32(v);
      W[t] = v;
    }

    for (int t = 16; t < 64; t++) {
      __Wt_ref(W, t);
    }

    uint32_t a, b, c, d, e, f, g, h;
    __load_H_ref(H, &a, &b, &c, &d, &e, &f, &g, &h);

    for (uint64_t tr = 0; tr < 64; tr++) {
      uint32_t T1 = h;
      uint32_t r  = __BSIG1_ref(e);
      T1 += r;
      r   = __CH_ref(e, f, g);
      T1 += r;
      T1 += SHA256_K[tr];
      T1 += W[tr];

      uint32_t T2 = __BSIG0_ref(a);
      r   = __MAJ_ref(a, b, c);
      T2 += r;

      h  = g;
      g  = f;
      f  = e;
      e  = d + T1;
      d  = c;
      c  = b;
      b  = a;
      a  = T1 + T2;
    }

    a += H[0];
    b += H[1];
    c += H[2];
    d += H[3];
    e += H[4];
    f += H[5];
    g += H[6];
    h += H[7];

    __store_H_ref(H, a, b, c, d, e, f, g, h);

    *in += 64;
    *inlen -= 64;
  }
}

static inline void _blocks_1_ref(uint32_t H[8], const uint32_t sblocks[32], uint64_t nblocks)
{
  uint32_t W[64];

  for (uint64_t i = 0; i < nblocks; i++) {
    uint64_t oblocks = i << 4;
    for (int t = 0; t < 16; t++) {
      uint32_t v = sblocks[oblocks + t];
      v = BSWAP32(v);
      W[t] = v;
    }

    for (int t = 16; t < 64; t++) {
      __Wt_ref(W, t);
    }

    uint32_t a, b, c, d, e, f, g, h;
    __load_H_ref(H, &a, &b, &c, &d, &e, &f, &g, &h);

    for (uint64_t tr = 0; tr < 64; tr++) {
      uint32_t T1 = h;
      uint32_t r  = __BSIG1_ref(e);
      T1 += r;
      r   = __CH_ref(e, f, g);
      T1 += r;
      T1 += SHA256_K[tr];
      T1 += W[tr];

      uint32_t T2 = __BSIG0_ref(a);
      r   = __MAJ_ref(a, b, c);
      T2 += r;

      h  = g;
      g  = f;
      f  = e;
      e  = d + T1;
      d  = c;
      c  = b;
      b  = a;
      a  = T1 + T2;
    }

    a += H[0];
    b += H[1];
    c += H[2];
    d += H[3];
    e += H[4];
    f += H[5];
    g += H[6];
    h += H[7];

    __store_H_ref(H, a, b, c, d, e, f, g, h);
  }
}

static inline uint64_t __lastblocks_ref(const uint8_t *in, uint64_t inlen, uint64_t bits, uint32_t sblocks[32])
{
  uint8_t *sb = (uint8_t *)sblocks;

  for (int k = 0; k < 32; k++) {
    sblocks[k] = 0;
  }

  uint64_t i = 0;
  while (i < inlen) {
    sb[i] = in[i];
    i += 1;
  }

  sb[i] = 0x80;

  uint64_t j, nblocks;
  if (inlen < 56) {
    j = (64 - 8);
    nblocks = 1;
    i = 63;
  } else {
    j = (128 - 8);
    nblocks = 2;
    i = 127;
  }

  while (i >= j) {
    sb[i] = (uint8_t)bits;
    bits >>= 8;
    if (i == 0) break;
    i -= 1;
  }

  return nblocks;
}

static inline void __sha256_ref(uint8_t *out, const uint8_t *in, uint64_t inlen)
{
  uint64_t bits = inlen << 3;
  uint32_t H[8];
  uint32_t sblocks[32];

  __initH_ref(H);
  _blocks_0_ref(H, &in, &inlen);

  uint64_t nblocks = __lastblocks_ref(in, inlen, bits, sblocks);
  _blocks_1_ref(H, sblocks, nblocks);

  __store_ref(out, H);
}

#endif

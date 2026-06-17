// Import libraries
#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/random.h>
#include <unistd.h>

// Declare the X86-64 program
extern int64_t main_test();

// RandomBytes Jasmin Syscall
uint8_t *__jasmin_syscall_randombytes__(uint8_t *_x, uint64_t xlen) {
  int i;
  uint8_t *x = _x;

  while (xlen > 0) {
    if (xlen < 1048576)
      i = xlen;
    else
      i = 1048576;

    i = getrandom(x, i, 0);
    if (i < 1) {
      sleep(1);
      continue;
    }
    x += i;
    xlen -= i;
  }

  return _x;
}

// Convert hex to bytes
void hex_to_bytes(const char *hex, uint8_t *bytes, size_t len) {
  for (size_t i = 0; i < len; i++) {
    sscanf(hex + 2 * i, "%02hhx", &bytes[i]);
  }
}

// Main
int main(int argc, char *argv[]) {
  if (argc < 3) {
    fprintf(stderr, "Usage: %s <size> <N> <val1> ... <valN>\n", argv[0]);
    return 1;
  }

  const int size = atoi(argv[1]);
  const int N = atoi(argv[2]);

  if (argc != 3 + N) {
    fprintf(stderr, "Error: Expected %d arguments, but got %d\n", N, argc - 3);
    return 1;
  }

  if (N > 6) {
    fprintf(stderr, "Error: Maximum 6 arguments supported by this wrapper.\n");
    return 1;
  }

  int64_t args[6] = {0};
  char *endptr;

  for (int i = 0; i < N; i++) {
    errno = 0;

    // Special case for SHA256-OPT
    if (strstr(argv[0], "sha256-opt") != NULL) {
      continue;
    }

    // Special case for SHA256
    if (strstr(argv[0], "sha256") != NULL) {
      continue;
    }

    // Special case for CHACHA20XORAVX-OPT
    if (strstr(argv[0], "chacha20xoravx-opt") != NULL) {
      continue;
    }

    // Special case for CHACHA20XORAVX
    if (strstr(argv[0], "chacha20xoravx") != NULL) {
      continue;
    }

    // Special case for CHACHA20AVX-OPT
    if (strstr(argv[0], "chacha20avx-opt") != NULL) {
      continue;
    }

    // Special case for CHACHA20AVX
    if (strstr(argv[0], "chacha20avx") != NULL) {
      continue;
    }

    // Special case for CHACHA20XOR-OPT
    if (strstr(argv[0], "chacha20xor-OPT") != NULL) {
      continue;
    }

    // Special case for CHACHA20XOR
    if (strstr(argv[0], "chacha20xor") != NULL) {
      continue;
    }

    // Special case for CHACHA20-OPT
    if (strstr(argv[0], "chacha20-opt") != NULL) {
      continue;
    }

    // Special case for CHACHA20
    if (strstr(argv[0], "chacha20") != NULL) {
      continue;
    }

    // Special case for GC001
    if (strstr(argv[0], "gc001") != NULL) {
      continue;
    }

    // Common cases
    if (size == 32) {

      long tmp = strtol(argv[3 + i], &endptr, 10);
      if (errno == ERANGE || tmp < INT32_MIN || tmp > INT32_MAX || *endptr != '\0') {
        fprintf(stderr, "Error: '%s' is not a valid 32-bit int.\n", argv[3 + i]);
        return 1;
      }
      args[i] = (int64_t)((int32_t)tmp);

    } else if (size == 64) {

      long long tmp = strtoll(argv[3 + i], &endptr, 10);
      if (errno == ERANGE || *endptr != '\0') {
        fprintf(stderr, "Error: '%s' is not a valid 64-bit int.\n", argv[3 + i]);
        return 1;
      }
      args[i] = (int64_t)tmp;

    } else {

      fprintf(stderr, "Error: Size should be equal to 32 or 64, not to %d.\n", size);
      return 1;

    }
  }

  int64_t res;
  uintptr_t func_ptr = (uintptr_t)main_test;

  // Special case for SHA256-OPT
  if (strstr(argv[0], "sha256-opt") != NULL) {
    char *input_str = argv[3];
    uint8_t *in_data;
    uint64_t len;

    if (strspn(input_str, "0123456789") == strlen(input_str)) {
      len = strtoull(input_str, NULL, 10);
      in_data = calloc(1, len > 0 ? len : 1);
    } else {
      len = strlen(input_str);
      in_data = (uint8_t *)input_str;
    }

    uint8_t out_array[32] = {0};
    uintptr_t func_ptr = (uintptr_t)main_test;
    ((void (*)(uint8_t*, uint8_t*, uint64_t))func_ptr)(out_array, in_data, len);

    for (int i = 0; i < 32; i++) printf("%02x", out_array[i]);
    printf("\n");

    return 0;
  }

  // Special case for SHA256
  if (strstr(argv[0], "sha256") != NULL) {
    char *input_str = argv[3];
    uint8_t *in_data;
    uint64_t len;

    if (strspn(input_str, "0123456789") == strlen(input_str)) {
      len = strtoull(input_str, NULL, 10);
      in_data = calloc(1, len > 0 ? len : 1);
    } else {
      len = strlen(input_str);
      in_data = (uint8_t *)input_str;
    }

    uint8_t out_array[32] = {0};
    uintptr_t func_ptr = (uintptr_t)main_test;
    ((void (*)(uint8_t*, uint8_t*, uint64_t))func_ptr)(out_array, in_data, len);

    for (int i = 0; i < 32; i++) printf("%02x", out_array[i]);
    printf("\n");

    return 0;
  }

  // Special case for CHACHA20XORAVX-OPT
  if (strstr(argv[0], "chacha20xoravx-opt") != NULL) {
    uint64_t len = strtoull(argv[3], NULL, 10);
    const char *input_hex = argv[4];
    const char *key_hex   = argv[5];
    const char *nonce_hex = argv[6];

    uint8_t *out = calloc(1, len > 0 ? len : 1);
    uint8_t *in  = calloc(1, len > 0 ? len : 1);
    uint8_t key[32] = {0};
    uint8_t nonce[12] = {0};

    if (len > 0) hex_to_bytes(input_hex, in, len);
    hex_to_bytes(key_hex, key, 32);
    hex_to_bytes(nonce_hex, nonce, 12);

    ((void (*)(uint8_t*, uint8_t*, uint64_t, uint8_t*, uint8_t*))func_ptr)(out, in, len, nonce, key);

    for (uint64_t i = 0; i < len; i++) printf("%02x", out[i]);
    printf("\n");

    free(out); free(in);
    return 0;
  }

  // Special case for CHACHA20XORAVX
  if (strstr(argv[0], "chacha20xoravx") != NULL) {
    uint64_t len = strtoull(argv[3], NULL, 10);
    const char *input_hex = argv[4];
    const char *key_hex   = argv[5];
    const char *nonce_hex = argv[6];

    uint8_t *out = calloc(1, len > 0 ? len : 1);
    uint8_t *in  = calloc(1, len > 0 ? len : 1);
    uint8_t key[32] = {0};
    uint8_t nonce[12] = {0};

    if (len > 0) hex_to_bytes(input_hex, in, len);
    hex_to_bytes(key_hex, key, 32);
    hex_to_bytes(nonce_hex, nonce, 12);

    ((void (*)(uint8_t*, uint8_t*, uint64_t, uint8_t*, uint8_t*))func_ptr)(out, in, len, nonce, key);

    for (uint64_t i = 0; i < len; i++) printf("%02x", out[i]);
    printf("\n");

    free(out); free(in);
    return 0;
  }

  // Special case for CHACHA20AVX-OPT
  if (strstr(argv[0], "chacha20avx-opt") != NULL) {
    uint64_t len = strtoull(argv[3], NULL, 10);
    const char *key_hex = argv[4];
    const char *nonce_hex = argv[5];

    uint8_t *out = calloc(1, len > 0 ? len : 1);
    uint8_t key[32] = {0};
    uint8_t nonce[12] = {0};

    hex_to_bytes(key_hex, key, 32);
    hex_to_bytes(nonce_hex, nonce, 12);

    uintptr_t func_ptr = (uintptr_t)main_test;
    ((void (*)(uint8_t*, uint64_t, uint8_t*, uint8_t*))func_ptr)(out, len, nonce, key);

    for (uint64_t i = 0; i < len; i++) printf("%02x", out[i]);
    printf("\n");

    free(out);
    return 0;
  }

  // Special case for CHACHA20AVX
  if (strstr(argv[0], "chacha20avx") != NULL) {
    uint64_t len = strtoull(argv[3], NULL, 10);
    const char *key_hex = argv[4];
    const char *nonce_hex = argv[5];

    uint8_t *out = calloc(1, len > 0 ? len : 1);
    uint8_t key[32] = {0};
    uint8_t nonce[12] = {0};

    hex_to_bytes(key_hex, key, 32);
    hex_to_bytes(nonce_hex, nonce, 12);

    uintptr_t func_ptr = (uintptr_t)main_test;
    ((void (*)(uint8_t*, uint64_t, uint8_t*, uint8_t*))func_ptr)(out, len, nonce, key);

    for (uint64_t i = 0; i < len; i++) printf("%02x", out[i]);
    printf("\n");

    free(out);
    return 0;
  }

  // Special case for CHACHA20XOR-OPT
  if (strstr(argv[0], "chacha20xor-opt") != NULL) {
    uint64_t len = strtoull(argv[3], NULL, 10);
    const char *input_hex = argv[4];
    const char *key_hex   = argv[5];
    const char *nonce_hex = argv[6];

    uint8_t *out = calloc(1, len > 0 ? len : 1);
    uint8_t *in  = calloc(1, len > 0 ? len : 1);
    uint8_t key[32] = {0};
    uint8_t nonce[12] = {0};

    if (len > 0) hex_to_bytes(input_hex, in, len);
    hex_to_bytes(key_hex, key, 32);
    hex_to_bytes(nonce_hex, nonce, 12);

    ((void (*)(uint8_t*, uint8_t*, uint64_t, uint8_t*, uint8_t*))func_ptr)(out, in, len, nonce, key);

    for (uint64_t i = 0; i < len; i++) printf("%02x", out[i]);
    printf("\n");

    free(out); free(in);
    return 0;
  }

  // Special case for CHACHA20XOR
  if (strstr(argv[0], "chacha20xor") != NULL) {
    uint64_t len = strtoull(argv[3], NULL, 10);
    const char *input_hex = argv[4];
    const char *key_hex   = argv[5];
    const char *nonce_hex = argv[6];

    uint8_t *out = calloc(1, len > 0 ? len : 1);
    uint8_t *in  = calloc(1, len > 0 ? len : 1);
    uint8_t key[32] = {0};
    uint8_t nonce[12] = {0};

    if (len > 0) hex_to_bytes(input_hex, in, len);
    hex_to_bytes(key_hex, key, 32);
    hex_to_bytes(nonce_hex, nonce, 12);

    ((void (*)(uint8_t*, uint8_t*, uint64_t, uint8_t*, uint8_t*))func_ptr)(out, in, len, nonce, key);

    for (uint64_t i = 0; i < len; i++) printf("%02x", out[i]);
    printf("\n");

    free(out); free(in);
    return 0;
  }

  // Special case for CHACHA20-OPT
  if (strstr(argv[0], "chacha20-opt") != NULL) {
    uint64_t len = strtoull(argv[3], NULL, 10);
    const char *key_hex = argv[4];
    const char *nonce_hex = argv[5];

    uint8_t *out = calloc(1, len > 0 ? len : 1);
    uint8_t key[32] = {0};
    uint8_t nonce[12] = {0};

    hex_to_bytes(key_hex, key, 32);
    hex_to_bytes(nonce_hex, nonce, 12);

    uintptr_t func_ptr = (uintptr_t)main_test;
    ((void (*)(uint8_t*, uint64_t, uint8_t*, uint8_t*))func_ptr)(out, len, nonce, key);

    for (uint64_t i = 0; i < len; i++) printf("%02x", out[i]);
    printf("\n");

    free(out);
    return 0;
  }

  // Special case for CHACHA20
  if (strstr(argv[0], "chacha20") != NULL) {
    uint64_t len = strtoull(argv[3], NULL, 10);
    const char *key_hex = argv[4];
    const char *nonce_hex = argv[5];

    uint8_t *out = calloc(1, len > 0 ? len : 1);
    uint8_t key[32] = {0};
    uint8_t nonce[12] = {0};

    hex_to_bytes(key_hex, key, 32);
    hex_to_bytes(nonce_hex, nonce, 12);

    uintptr_t func_ptr = (uintptr_t)main_test;
    ((void (*)(uint8_t*, uint64_t, uint8_t*, uint8_t*))func_ptr)(out, len, nonce, key);

    for (uint64_t i = 0; i < len; i++) printf("%02x", out[i]);
    printf("\n");

    free(out);
    return 0;
  }

  // Special case for GC001
  if (strstr(argv[0], "gc001") != NULL) {
    long val = strtol(argv[3], &endptr, 10);
    if (errno == ERANGE || val < INT32_MIN || val > INT32_MAX || *endptr != '\0') {
      fprintf(stderr, "Error: '%s' is not a valid 32-bit int.\n", argv[3]);
      return 1;
    }
    uint32_t x = (uint32_t)val;

    uint8_t  t1[32] = {0};
    uint16_t t2[16] = {0};
    uint32_t t3[ 8] = {0};
    uint64_t t4[ 4] = {0};

    uintptr_t func_ptr = (uintptr_t)main_test;
    res = ((uint32_t (*)(uint8_t*, uint16_t*, uint32_t*, uint64_t*, uint32_t))func_ptr)(t1, t2, t3, t4, x);

    printf("%" PRId32 "\n", (int32_t)res);
    return 0;
  }

  // Common cases
  switch (N) {
    case 0:
      res = main_test();
      break;
    case 1:
      res = ((int64_t (*)(int64_t))func_ptr)(args[0]);
      break;
    case 2:
      res = ((int64_t (*)(int64_t, int64_t))func_ptr)(args[0], args[1]);
      break;
    case 3:
      res = ((int64_t (*)(int64_t, int64_t, int64_t))func_ptr)(args[0], args[1], args[2]);
      break;
    case 4:
      res = ((int64_t (*)(int64_t, int64_t, int64_t, int64_t))func_ptr)(args[0], args[1], args[2], args[3]);
      break;
    case 5:
      res = ((int64_t (*)(int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(args[0], args[1], args[2], args[3], args[4]);
      break;
    case 6:
      res = ((int64_t (*)(int64_t, int64_t, int64_t, int64_t, int64_t, int64_t))func_ptr)(args[0], args[1], args[2], args[3], args[4], args[5]);
      break;
    default:
      return 1;
  }

  if (size == 32) printf("%" PRId32 "\n", (int32_t)res);
  else if (size == 64) printf("%" PRId64 "\n", res);
  else {
    fprintf(stderr, "Error: Size should be equal to 32 or 64, not to %d.\n", size);
    return 1;
  }

  return 0;
}

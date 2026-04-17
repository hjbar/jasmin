// Import libraries
#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/random.h>
#include <unistd.h>

// Declare the X86-64 program
extern int64_t main_test(int64_t);

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

// Main
int main(int argc, char *argv[]) {
  if (argc != 3) {
    fprintf(stderr, "Usage: %s <size> <number>\n", argv[0]);
    return 1;
  }

  char *endptr;
  errno = 0;
  const int size = atoi(argv[1]);

  if (size == 32) {
    const long tmp = strtol(argv[2], &endptr, 10);

    if (errno == ERANGE || tmp < INT32_MIN || tmp > INT32_MAX ||
        *endptr != '\0') {
      fprintf(stderr, "Error : '%s' is not a valid 32 bits integer.\n",
              argv[1]);
      return 1;
    }

    const int32_t number = (int32_t)tmp;
    const int32_t res = (int32_t)main_test((int64_t)number);
    printf("%" PRId32 "\n", res);
    return 0;
  } else if (size == 64) {
    const long long tmp = strtoll(argv[2], &endptr, 10);

    if (errno == ERANGE || *endptr != '\0') {
      fprintf(stderr, "Error : '%s' is not a valid 64 bits integer.\n",
              argv[1]);
      return 1;
    }

    const int64_t number = (int64_t)tmp;
    const int64_t res = main_test(number);
    printf("%" PRId64 "\n", res);
    return 0;
  } else {
    fprintf(stderr, "Error: Size should be equal to 32 or 64, not to %d.\n",
            size);
    return 1;
  }
}

// Import libraries
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <errno.h>
#include <limits.h>

// Declare the X86-64 program
extern int64_t main_test(int64_t);

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

    if (errno == ERANGE || tmp < INT32_MIN || tmp > INT32_MAX || *endptr != '\0') {
      fprintf(stderr, "Error : '%s' is not a valid 32 bits integer.\n", argv[1]);
      return 1;
    }

    const int32_t number = (int32_t)tmp;
    const int32_t res = (int32_t)main_test((int64_t)number);
    printf("%" PRId32 "\n", res);
    return 0;
  }
  else if (size == 64) {
    const long long tmp = strtoll(argv[2], &endptr, 10);

    if (errno == ERANGE || *endptr != '\0') {
      fprintf(stderr, "Error : '%s' is not a valid 64 bits integer.\n", argv[1]);
      return 1;
    }

    const int64_t number = (int64_t)tmp;
    const int64_t res = main_test(number);
    printf("%" PRId64 "\n", res);
    return 0;
  }
  else {
    fprintf(stderr, "Error: Size should be equal to 32 or 64, not to %d.\n", size);
    return 1;
  }
}

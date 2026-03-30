#!/bin/bash

# Globals
ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PARENT_DIR=$(dirname "$ROOT_DIR")

COMPILER="$PARENT_DIR/jasminc"
FILES_32="$ROOT_DIR/tests_32"
FILES_64="$ROOT_DIR/tests_64"

VALUES=(0 1 10 42 100 -1 -10 -42 -100)

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

SEP="=========================================================================================="

# Run the tests
run_tests() {
  local FILES="$1"
  local SIZE="$2"

  # Test on every *.jazz files
  for path in "$FILES"/*.jazz; do
    # Skip if the path is not correct
    [ -e "$path" ] || continue

    # Get the basename of the path
    base=$(basename "$path" .jazz)

    # Main files
    f_jazz="$FILES/$base.jazz"
    f_c="$ROOT_DIR/main.c"
    f_js="$ROOT_DIR/main.js"

    # Build files
    f_s="$FILES/$base.s"
    f_main_o="$FILES/${base}_main.o"
    f_o="$FILES/$base.o"
    f_exe="$FILES/$base.exe"
    f_wat="$FILES/$base.wat"
    f_wasm="$FILES/$base.wasm"

    # Separator
    printf "\n%s\n\n" "$SEP"

    # Compile to x86-64
    printf "Compile $base to x86-64...\n\n"
    "$COMPILER" -arch x86-64 -pasm -nowarning "$f_jazz" > "$f_s" || continue
    gcc -c "$f_c" -o "$f_main_o" || continue
    gcc -c "$f_s" -o "$f_o" || continue
    gcc -no-pie "$f_main_o" "$f_o" -o "$f_exe" || continue

    # Compile to Wasm
    printf "Compile $base to Wasm...\n\n"
    "$COMPILER" -arch wasm -pasm -nowarning "$f_jazz" > "$f_wat" || continue
    wat2wasm "$f_wat" -o "$f_wasm" || continue

    # Compare results
    echo "Test $f_jazz :"

    for val in "${VALUES[@]}"; do
      printf "[Input %4s] : " "$val"

      RESULT_X86=$("$f_exe" "$SIZE" "$val")
      RESULT_WASM=$(node "$f_js" "$f_wasm" "$SIZE" "$val")

      if [ "$RESULT_X86" == "$RESULT_WASM" ]; then
        printf "${GREEN}%S${NC} %-10s\n" "OK" "$RESULT_WASM"
      else
        printf "${RED}%S${NC} X86: %-10s | WASM: %s\n" "ERROR" "$RESULT_X86" "$RESULT_WASM"
      fi
    done

    # Remove build files
    rm -f "$f_s" "$f_main_o" "$f_o" "$f_exe" "$f_wat" "$f_wasm"
  done
}

# Build Jasminc compiler
echo "Build..."
make -C "$PARENT_DIR"
clear

# Run the tests
run_tests "$FILES_32" 32
run_tests "$FILES_64" 64

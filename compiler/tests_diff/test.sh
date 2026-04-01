#!/bin/bash

# Parse command line
VERBOSE=false
ALL=false
CLEAN=false

while getopts "vac" opt; do
  case $opt in
    v)
      VERBOSE=true
      ;;
    a)
      ALL=true
      ;;
    c)
      CLEAN=true
      ;;
    \?)
      echo "Invalid option : -$OPTARG" >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

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

  # Flag for non-verbose mode
  error=false

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
    if [ "$VERBOSE" = true ]; then
      printf "\n%s\n\n" "$SEP"
    elif [ "$error" = true ]; then
      printf "\n"
    fi

    # Reset flag for non-verbose mode
    error=false

    # Compile to x86-64
    if [ "$VERBOSE" = true ]; then
      printf "Compile $base to x86-64...\n\n"
    fi
    "$COMPILER" -arch x86-64 -pasm -nowarning "$f_jazz" > "$f_s" || { error=true; continue; }
    gcc -c "$f_c" -o "$f_main_o" || { error=true; continue; }
    gcc -c "$f_s" -o "$f_o" || { error=true; continue; }
    gcc -no-pie "$f_main_o" "$f_o" -o "$f_exe" || { error=true; continue; }

    # Compile to Wasm
    if [ "$VERBOSE" = true ]; then
      printf "Compile $base to Wasm...\n\n"
    fi
    "$COMPILER" -arch wasm -pasm -nowarning "$f_jazz" > "$f_wat" || { error=true; continue; }
    wat2wasm "$f_wat" -o "$f_wasm" || { error=true; continue; }

    # Compare results
    if [ "$VERBOSE" = true ]; then
      echo "Test $f_jazz :"
    fi

    for val in "${VALUES[@]}"; do
      RESULT_X86=$("$f_exe" "$SIZE" "$val")
      RESULT_WASM=$(node "$f_js" "$f_wasm" "$SIZE" "$val")

      if [ "$RESULT_X86" == "$RESULT_WASM" ]; then
        if [ "$VERBOSE" = true ]; then
          printf "[Input %4s] : ${GREEN}%s${NC} %-10s\n" "$val" "OK" "$RESULT_WASM"
        fi
      else
        error=true
        if [ "$VERBOSE" = true ]; then
          printf "[Input %4s] : ${RED}%s${NC} X86: %-10s | WASM: %s\n" "$val" "ERROR" "$RESULT_X86" "$RESULT_WASM"
        else
          printf "[Input %4s] : ${RED}%s${NC} X86: %-10s | WASM: %-10s (%s)\n" "$val" "ERROR" "$RESULT_X86" "$RESULT_WASM" "$f_jazz"
        fi
      fi
    done

    # Remove build files
    if [ "$CLEAN" = true ]; then
      rm -f "$f_s" "$f_main_o" "$f_o" "$f_exe" "$f_wat" "$f_wasm"
    fi
  done
}

# Build Jasminc compiler
echo "Build..."
make -C "$PARENT_DIR"
clear

# Run the tests
if [ "$ALL" = true ]; then
  run_tests "$FILES_32" 32
  run_tests "$FILES_64" 64
else
  run_tests "$FILES_32" 32
fi

# Remove build files
if [ "$CLEAN" = true ]; then
  rm -f "$FILES_32"/*.{s,o,exe,wat,wasm}
  rm -f "$FILES_64"/*.{s,o,exe,wat,wasm}
fi

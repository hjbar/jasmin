#!/bin/bash

# Parse command line
VERBOSE=false
CLEAN=false

while getopts "vc" opt; do
  case $opt in
    v)
      VERBOSE=true
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
GIMLI="$ROOT_DIR/gimli"

VALUES=(0 1 10 42 100 -1 -10 -42 -100)

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

SEP="=========================================================================================="

# Run the tests
run_tests() {
  local FILES="$1"
  local SIZE="$2"

  # Base directory name
  local DIR_NAME=$(basename "$FILES")

  # Flag for non-verbose mode
  local error=false

  # Main files
  local ref_file="$FILES/ref/${DIR_NAME}_ref.jazz"
  local f_c="$ROOT_DIR/main.c"

  # Build files
  local f_s="$FILES/ref/${DIR_NAME}_ref.s"
  local f_main_o="$FILES/ref/${DIR_NAME}_ref_main.o"
  local f_o="$FILES/ref/${DIR_NAME}_ref.o"
  local f_exe="$FILES/ref/${DIR_NAME}_ref.exe"

  # Compile to x86-64
  if [ "$VERBOSE" = true ]; then
    printf "Compile $base to x86-64...\n\n"
  fi
  "$COMPILER" -arch x86-64 -pasm -nowarning "$ref_file" > "$f_s" || { echo -e "${RED}Error compiling $ref_file to x86${NC}"; return; }
  gcc -c "$f_c" -o "$f_main_o" || { echo -e "${RED}Error compiling main.c${NC}"; return; }
  gcc -c "$f_s" -o "$f_o" || { echo -e "${RED}Error assembling $f_s${NC}"; return; }
  gcc -no-pie "$f_main_o" "$f_o" -o "$f_exe" || { echo -e "${RED}Error linking x86 executable${NC}"; return; }

  # Test on every *.jazz files
  for path in "$FILES/prog"/*.jazz; do
    # Skip if the path is not correct
    [ -e "$path" ] || continue

    # Get the basename of the path
    local base=$(basename "$path" .jazz)

    # Main files
    local f_jazz="$FILES/prog/$base.jazz"
    local f_js="$ROOT_DIR/main.js"

    # Build files
    local f_wat="$FILES/prog/$base.wat"
    local f_wasm="$FILES/prog/$base.wasm"

    # Separator
    if [ "$VERBOSE" = true ]; then
      printf "\n%s\n\n" "$SEP"
    elif [ "$error" = true ]; then
      printf "\n"
    fi

    # Reset flag for non-verbose mode
    error=false

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
          printf "[Input %4s] : ${GREEN}%s${NC} %-15s\n" "$val" "OK" "$RESULT_WASM"
        fi
      else
        error=true
        if [ "$VERBOSE" = true ]; then
          printf "[Input %4s] : ${RED}%s${NC} X86: %-15s | WASM: %s\n" "$val" "ERROR" "$RESULT_X86" "$RESULT_WASM"
        else
          printf "[Input %4s] : ${RED}%s${NC} X86: %-15s | WASM: %-15s (%s)\n" "$val" "ERROR" "$RESULT_X86" "$RESULT_WASM" "$f_jazz"
        fi
      fi
    done

    # Remove build files
    if [ "$CLEAN" = true ]; then
      rm -f "$f_wat" "$f_wasm"
    fi
  done
}

# Build Jasminc compiler
echo "Build..."
make -C "$PARENT_DIR"
clear

# Run the tests
run_tests "$GIMLI" 32

# Remove build files
if [ "$CLEAN" = true ]; then
  rm -f "$GIMLI/ref"/*.{s,o,exe}
  rm -f "$GIMLI/prog"/*.{wat,wasm}
fi

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

VALUES=(0 1 10 42 100 -1 -10 -42 -100)

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

SEP="=========================================================================================="

# Run the tests
run_tests() {
  local f_jazz="$1"
  local SIZE="$2"
  shift 2
  local EXPECTED=("$@")

  if [ ! -f "$f_jazz" ]; then
    echo -e "${RED}Error: File $f_jazz not found.${NC}"
    return 1
  fi

  if [ "${#VALUES[@]}" -ne "${#EXPECTED[@]}" ]; then
    echo -e "${RED}Error: Number of expected results (${#EXPECTED[@]}) is not equal to the number of tested values (${#VALUES[@]}).${NC}"
    return 1
  fi

  # Get the basename and the dir of the path
  local base=$(basename "$f_jazz" .jazz)
  local dir=$(dirname "$f_jazz")

  # Main file
  local f_js="$ROOT_DIR/main.js"

  # Build files
  local f_wat="$dir/$base.wat"
  local f_wasm="$dir/$base.wasm"

  # Flag for non-verbose mode
  local error=false

  # Separator
  if [ "$VERBOSE" = true ]; then
    printf "\n%s\n\n" "$SEP"
  elif [ "$error" = true ]; then
    printf "\n"
  fi

  # Compile to Wasm
  if [ "$VERBOSE" = true ]; then
    printf "Compile $base to Wasm...\n\n"
  fi
  "$COMPILER" -arch wasm -pasm -nowarning "$f_jazz" > "$f_wat" || { echo -e "${RED}Compilation error (jasminc)${NC}"; return 1; }
  wat2wasm "$f_wat" -o "$f_wasm" || { echo -e "${RED}Compilation error (wat2wasm)${NC}"; return 1; }

  # Compare results
  if [ "$VERBOSE" = true ]; then
    echo "Test $f_jazz :"
  fi

  for i in "${!VALUES[@]}"; do
    local val="${VALUES[$i]}"
    local expected="${EXPECTED[$i]}"

    RESULT_WASM=$(node "$f_js" "$f_wasm" "$SIZE" "$val")

    if [ "$RESULT_WASM" == "$expected" ]; then
      if [ "$VERBOSE" = true ]; then
        printf "[Input %4s] : ${GREEN}%s${NC} %-19s\n" "$val" "OK" "$RESULT_WASM"
      fi
    else
      error=true
      if [ "$VERBOSE" = true ]; then
        printf "[Input %4s] : ${RED}%s${NC} EXPECTED: %-19s | WASM: %s\n" "$val" "ERROR" "$expected" "$RESULT_WASM"
      else
        printf "[Input %4s] : ${RED}%s${NC} EXPECTED: %-19s | WASM: %-19s (%s)\n" "$val" "ERROR" "$expected" "$RESULT_WASM" "$f_jazz"
      fi
    fi    done

  # Remove build files
  if [ "$CLEAN" = true ]; then
    rm -f "$f_wat" "$f_wasm"
  fi

  [ "$error" = true ] && return 1 || return 0
}

# Build Jasminc compiler
echo "Build..."
make -C "$PARENT_DIR"
clear

# Run the tests
EXPECTED_RESULTS_64=("0" "1" "42" "10" "100" "-1" "-42" "-10" "-100")
run_tests "$ROOT_DIR/wasm_64/vec_64.jazz" 64 "${EXPECTED_RESULTS_64[@]}"

# Remove build files
if [ "$CLEAN" = true ]; then
  rm -f "$WASM_32"/*.{wat,wasm}
  rm -f "$WASM_64"/*.{wat,wasm}
fi

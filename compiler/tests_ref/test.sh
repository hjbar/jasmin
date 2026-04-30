#!/bin/bash


# Parse command line
VERBOSE=false
CLEAN=false
UNFOLD=false

while getopts "vcu" opt; do
  case $opt in
    v)
      VERBOSE=true
      ;;
    c)
      CLEAN=true
      ;;
    u)
      UNFOLD=true
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

SHA256="$ROOT_DIR/sha256"
SHA256_OPT="$ROOT_DIR/sha256-opt"

CHACHA20="$ROOT_DIR/chacha20"
CHACHA20_OPT="$ROOT_DIR/chacha20-opt"

CHACHA20AVX="$ROOT_DIR/chacha20avx"
CHACHA20AVX_OPT="$ROOT_DIR/chacha20avx-opt"

CHACHA20XOR="$ROOT_DIR/chacha20xor"
CHACHA20XOR_OPT="$ROOT_DIR/chacha20xor-opt"

CHACHA20XORAVX="$ROOT_DIR/chacha20xoravx"
CHACHA20XORAVX_OPT="$ROOT_DIR/chacha20xoravx-opt"

FILES_32=("$GIMLI")
FILES_64=(
  "$SHA256"         "$SHA256_OPT"
  "$CHACHA20"       "$CHACHA20_OPT"
  "$CHACHA20AVX"    "$CHACHA20AVX_OPT"
  "$CHACHA20XOR"    "$CHACHA20XOR_OPT"
  "$CHACHA20XORAVX" "$CHACHA20XORAVX_OPT"
)
FILES_ALL=("${FILES_32[@]}" "${FILES_64[@]}")

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

SEP="=========================================================================================="
sep="------------------------------------------------------------------------------------------"


# Test function
run_tests() {
  local FILES="$1"
  local SIZE="$2"
  local N="$3"
  shift 3
  local VALUES=("$@")
  local VALUES_LENGTH=${#VALUES[@]}

  local max_width=0
  for item in "${VALUES[@]}"; do
    local display="$item"

    if [ ${#item} -gt 16 ] && [ $UNFOLD = false ]; then
      display="..."
    fi

    if [ ${#display} -gt $max_width ]; then
      max_width=${#display}
    fi
  done

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

  # Separator
  if [ "$VERBOSE" = true ]; then
    printf "\n%s\n\n" "$SEP"
  elif [ "$error" = true ]; then
    printf "\n"
  fi

  # Compile to x86-64
  if [ "$VERBOSE" = true ]; then
    printf "Compile ${DIR_NAME}_ref to x86-64...\n"
  fi
  "$COMPILER" -arch x86-64 -pasm -nowarning "$ref_file" > "$f_s" || { echo -e "${RED}Error compiling $ref_file to x86${NC}"; return; }
  gcc -Wno-cast-function-type -c "$f_c" -o "$f_main_o" || { echo -e "${RED}Error compiling main.c${NC}"; return; }
  gcc -Wno-cast-function-type -c "$f_s" -o "$f_o" || { echo -e "${RED}Error assembling $f_s${NC}"; return; }
  gcc -Wno-cast-function-type -no-pie "$f_main_o" "$f_o" -o "$f_exe" || { echo -e "${RED}Error linking x86 executable${NC}"; return; }

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
      printf "\n%s\n\n" "$sep"
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

    for (( i=0; i<VALUES_LENGTH; i+=N )); do
      local val=("${VALUES[@]:i:N}")

      local input=""
      for item in "${val[@]}"; do
        local display="$item"

        if [ ${#item} -gt 16 ] && [ $UNFOLD = false ]; then
          display="..."
        fi

        local tmp=$(printf "%-${max_width}s" "$display")
        input="$input$tmp "
      done

      RESULT_X86=$("$f_exe" "$SIZE" "$N" "${val[@]}")
      FAIL_X86=$?

      RESULT_WASM=$(node "$f_js" "$f_wasm" "$SIZE" "$N" "${val[@]}")
      FAIL_WASM=$?

      if [ $FAIL_X86 -ne 0 ] || [ $FAIL_WASM -ne 0 ]; then
        error=true
        printf "[ Input %s] : ${RED}%s${NC} CRASH ! (X86 status: %s | WASM status: %s)\n" "$input" "ERROR" "$FAIL_X86" "$FAIL_WASM"
      elif [ "$RESULT_X86" == "$RESULT_WASM" ]; then
        if [ "$VERBOSE" = true ]; then
          printf "[ Input %s] : ${GREEN}%s${NC} %-15s\n" "$input" "OK" "$RESULT_WASM"
        fi
      else
        error=true
        if [ "$VERBOSE" = true ]; then
          printf "[ Input %s] : ${RED}%s${NC} X86: %-15s | WASM: %s\n" "$input" "ERROR" "$RESULT_X86" "$RESULT_WASM"
        else
          printf "[ Input %s] : ${RED}%s${NC} X86: %-15s | WASM: %-15s (%s)\n" "$input" "ERROR" "$RESULT_X86" "$RESULT_WASM" "$f_jazz"
        fi
      fi
    done

    # Remove build files
    if [ "$CLEAN" = true ]; then
      rm -f "$f_wat" "$f_wasm"
    fi
  done
}


# Generate a random hexa string
generate_string() {
  openssl rand -hex "$1"
}


# Build Jasminc compiler
echo "Build..."
make -C "$PARENT_DIR"
clear


# Run the tests

# GIMLI
VALUES=(0 1 10 42 100 -1 -10 -42 -100)
run_tests "$GIMLI" 32 1 "${VALUES[@]}"


# SHA256
V_001=$(printf '%.1s' {a..z}{1..32})
V_002=$(printf '%.1s' {a..z}{1..64})
V_003=$(printf '%.1s' {a..z}{1..128})
V_004=$(printf '%.1s' {a..z}{1..256})
V_005=$(printf '%.1s' {a..z}{1..2048})
VALUES=("0" "abc" "Hello World!" "foo bar gee" "$V_001" "$V_002" "$V_003" "$V_004" "$V_005")
run_tests "$SHA256" 64 1 "${VALUES[@]}"
run_tests "$SHA256_OPT" 64 1 "${VALUES[@]}"


# CHACHA20
K_ZER="0000000000000000000000000000000000000000000000000000000000000000"
K_SEQ="000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
K_RFC="808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"

N_ZER="000000000000000000000000"
N_FFF="ffffffffffffffffffffffff"
N_RFC="070000004041424344454647"

VALUES=(
# [LEN]  [KEY]    [NONCE]
  "0"    "$K_ZER" "$N_ZER"
  "1"    "$K_ZER" "$N_ZER"
  "64"   "$K_ZER" "$N_ZER"
  "65"   "$K_ZER" "$N_ZER"
  "128"  "$K_ZER" "$N_ZER"
  "256"  "$K_ZER" "$N_ZER"
  "2048" "$K_ZER" "$N_ZER"

  "0"    "$K_ZER" "$N_FFF"
  "1"    "$K_ZER" "$N_FFF"
  "64"   "$K_ZER" "$N_FFF"
  "65"   "$K_ZER" "$N_FFF"
  "128"  "$K_ZER" "$N_FFF"
  "256"  "$K_ZER" "$N_FFF"
  "2048" "$K_ZER" "$N_FFF"

  "0"    "$K_ZER" "$N_RFC"
  "1"    "$K_ZER" "$N_RFC"
  "64"   "$K_ZER" "$N_RFC"
  "65"   "$K_ZER" "$N_RFC"
  "128"  "$K_ZER" "$N_RFC"
  "256"  "$K_ZER" "$N_RFC"
  "2048" "$K_ZER" "$N_RFC"


  "0"    "$K_SEQ" "$N_ZER"
  "1"    "$K_SEQ" "$N_ZER"
  "64"   "$K_SEQ" "$N_ZER"
  "65"   "$K_SEQ" "$N_ZER"
  "128"  "$K_SEQ" "$N_ZER"
  "256"  "$K_SEQ" "$N_ZER"
  "2048" "$K_SEQ" "$N_ZER"

  "0"    "$K_SEQ" "$N_FFF"
  "1"    "$K_SEQ" "$N_FFF"
  "64"   "$K_SEQ" "$N_FFF"
  "65"   "$K_SEQ" "$N_FFF"
  "128"  "$K_SEQ" "$N_FFF"
  "256"  "$K_SEQ" "$N_FFF"
  "2048" "$K_SEQ" "$N_FFF"

  "0"    "$K_SEQ" "$N_RFC"
  "1"    "$K_SEQ" "$N_RFC"
  "64"   "$K_SEQ" "$N_RFC"
  "65"   "$K_SEQ" "$N_RFC"
  "128"  "$K_SEQ" "$N_RFC"
  "256"  "$K_SEQ" "$N_RFC"
  "2048" "$K_SEQ" "$N_RFC"


  "0"    "$K_RFC" "$N_ZER"
  "1"    "$K_RFC" "$N_ZER"
  "64"   "$K_RFC" "$N_ZER"
  "65"   "$K_RFC" "$N_ZER"
  "128"  "$K_RFC" "$N_ZER"
  "256"  "$K_RFC" "$N_ZER"
  "2048" "$K_RFC" "$N_ZER"

  "0"    "$K_RFC" "$N_FFF"
  "1"    "$K_RFC" "$N_FFF"
  "64"   "$K_RFC" "$N_FFF"
  "65"   "$K_RFC" "$N_FFF"
  "128"  "$K_RFC" "$N_FFF"
  "256"  "$K_RFC" "$N_FFF"
  "2048" "$K_RFC" "$N_FFF"

  "0"    "$K_RFC" "$N_RFC"
  "1"    "$K_RFC" "$N_RFC"
  "64"   "$K_RFC" "$N_RFC"
  "65"   "$K_RFC" "$N_RFC"
  "128"  "$K_RFC" "$N_RFC"
  "256"  "$K_RFC" "$N_RFC"
  "2048" "$K_RFC" "$N_RFC"
)
run_tests "$CHACHA20" 64 3 "${VALUES[@]}"
run_tests "$CHACHA20_OPT" 64 3 "${VALUES[@]}"
run_tests "$CHACHA20AVX" 64 3 "${VALUES[@]}"
run_tests "$CHACHA20AVX_OPT" 64 3 "${VALUES[@]}"


# CHACHA20 XOR
M_000="" #0
M_001="00" #1
M_002="ff" #1
M_003="48656c6c6f20576f726c6421" #12
M_004=$(printf '61%.0s' {1..64}) #64
M_005=$(printf '61%.0s' {1..65}) #65
M_006=$(printf '61%.0s' {1..128}) #128
M_007=$(generate_string 256) #256
M_008=$(generate_string 2048) #2048

K_ZER="0000000000000000000000000000000000000000000000000000000000000000"
K_SEQ="000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
K_RFC="808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"

N_ZER="000000000000000000000000"
N_FFF="ffffffffffffffffffffffff"
N_RFC="070000004041424344454647"

VALUES=(
# [LEN]  [INPUT]  [KEY]    [NONCE]
  "0"    "$M_000" "$K_ZER" "$N_ZER"
  "1"    "$M_001" "$K_ZER" "$N_ZER"
  "1"    "$M_002" "$K_ZER" "$N_ZER"
  "12"   "$M_003" "$K_ZER" "$N_ZER"
  "64"   "$M_004" "$K_ZER" "$N_ZER"
  "65"   "$M_005" "$K_ZER" "$N_ZER"
  "128"  "$M_006" "$K_ZER" "$N_ZER"
  "256"  "$M_007" "$K_ZER" "$N_ZER"
  "2048" "$M_008" "$K_ZER" "$N_ZER"

  "0"    "$M_000" "$K_ZER" "$N_FFF"
  "1"    "$M_001" "$K_ZER" "$N_FFF"
  "1"    "$M_002" "$K_ZER" "$N_FFF"
  "12"   "$M_003" "$K_ZER" "$N_FFF"
  "64"   "$M_004" "$K_ZER" "$N_FFF"
  "65"   "$M_005" "$K_ZER" "$N_FFF"
  "128"  "$M_006" "$K_ZER" "$N_FFF"
  "256"  "$M_007" "$K_ZER" "$N_FFF"
  "2048" "$M_008" "$K_ZER" "$N_FFF"

  "0"    "$M_000" "$K_ZER" "$N_RFC"
  "1"    "$M_001" "$K_ZER" "$N_RFC"
  "1"    "$M_002" "$K_ZER" "$N_RFC"
  "12"   "$M_003" "$K_ZER" "$N_RFC"
  "64"   "$M_004" "$K_ZER" "$N_RFC"
  "65"   "$M_005" "$K_ZER" "$N_RFC"
  "128"  "$M_006" "$K_ZER" "$N_RFC"
  "256"  "$M_007" "$K_ZER" "$N_RFC"
  "2048" "$M_008" "$K_ZER" "$N_RFC"


  "0"    "$M_000" "$K_SEQ" "$N_ZER"
  "1"    "$M_001" "$K_SEQ" "$N_ZER"
  "1"    "$M_002" "$K_SEQ" "$N_ZER"
  "12"   "$M_003" "$K_SEQ" "$N_ZER"
  "64"   "$M_004" "$K_SEQ" "$N_ZER"
  "65"   "$M_005" "$K_SEQ" "$N_ZER"
  "128"  "$M_006" "$K_SEQ" "$N_ZER"
  "256"  "$M_007" "$K_SEQ" "$N_ZER"
  "2048" "$M_008" "$K_SEQ" "$N_ZER"

  "0"    "$M_000" "$K_SEQ" "$N_FFF"
  "1"    "$M_001" "$K_SEQ" "$N_FFF"
  "1"    "$M_002" "$K_SEQ" "$N_FFF"
  "12"   "$M_003" "$K_SEQ" "$N_FFF"
  "64"   "$M_004" "$K_SEQ" "$N_FFF"
  "65"   "$M_005" "$K_SEQ" "$N_FFF"
  "128"  "$M_006" "$K_SEQ" "$N_FFF"
  "256"  "$M_007" "$K_SEQ" "$N_FFF"
  "2048" "$M_008" "$K_SEQ" "$N_FFF"

  "0"    "$M_000" "$K_SEQ" "$N_RFC"
  "1"    "$M_001" "$K_SEQ" "$N_RFC"
  "1"    "$M_002" "$K_SEQ" "$N_RFC"
  "12"   "$M_003" "$K_SEQ" "$N_RFC"
  "64"   "$M_004" "$K_SEQ" "$N_RFC"
  "65"   "$M_005" "$K_SEQ" "$N_RFC"
  "128"  "$M_006" "$K_SEQ" "$N_RFC"
  "256"  "$M_007" "$K_SEQ" "$N_RFC"
  "2048" "$M_008" "$K_SEQ" "$N_RFC"


  "0"    "$M_000" "$K_RFC" "$N_ZER"
  "1"    "$M_001" "$K_RFC" "$N_ZER"
  "1"    "$M_002" "$K_RFC" "$N_ZER"
  "12"   "$M_003" "$K_RFC" "$N_ZER"
  "64"   "$M_004" "$K_RFC" "$N_ZER"
  "65"   "$M_005" "$K_RFC" "$N_ZER"
  "128"  "$M_006" "$K_RFC" "$N_ZER"
  "256"  "$M_007" "$K_RFC" "$N_ZER"
  "2048" "$M_008" "$K_RFC" "$N_ZER"

  "0"    "$M_000" "$K_RFC" "$N_FFF"
  "1"    "$M_001" "$K_RFC" "$N_FFF"
  "1"    "$M_002" "$K_RFC" "$N_FFF"
  "12"   "$M_003" "$K_RFC" "$N_FFF"
  "64"   "$M_004" "$K_RFC" "$N_FFF"
  "65"   "$M_005" "$K_RFC" "$N_FFF"
  "128"  "$M_006" "$K_RFC" "$N_FFF"
  "256"  "$M_007" "$K_RFC" "$N_FFF"
  "2048" "$M_008" "$K_RFC" "$N_FFF"

  "0"    "$M_000" "$K_RFC" "$N_RFC"
  "1"    "$M_001" "$K_RFC" "$N_RFC"
  "1"    "$M_002" "$K_RFC" "$N_RFC"
  "12"   "$M_003" "$K_RFC" "$N_RFC"
  "64"   "$M_004" "$K_RFC" "$N_RFC"
  "65"   "$M_005" "$K_RFC" "$N_RFC"
  "128"  "$M_006" "$K_RFC" "$N_RFC"
  "256"  "$M_007" "$K_RFC" "$N_RFC"
  "2048" "$M_008" "$K_RFC" "$N_RFC"
)
run_tests "$CHACHA20XOR" 64 4 "${VALUES[@]}"
run_tests "$CHACHA20XOR_OPT" 64 4 "${VALUES[@]}"
run_tests "$CHACHA20XORAVX" 64 4 "${VALUES[@]}"
run_tests "$CHACHA20XORAVX_OPT" 64 4 "${VALUES[@]}"


# Remove build files
if [ "$CLEAN" = true ]; then
  for folder in "${FILES_ALL[@]}"; do
    rm -f "$folder/ref"/*.{s,o,exe}
    rm -f "$folder/prog"/*.{wat,wasm}
  done
fi

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
  wasm-as --all-features "$f_wat" -o "$f_wasm" || { echo -e "${RED}Compilation error (wasm-as)${NC}"; return 1; }

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

  # Separator
  if [ "$VERBOSE" = false ]; then
    if [ "$error" = true ]; then
      printf "\n"
    fi
  fi

  [ "$error" = true ] && return 1 || return 0
}

# Build Jasminc compiler
echo "Build..."
make -C "$PARENT_DIR"
clear

# Run the tests
EXPECTED_RESULTS=("0" "1" "10" "42" "100" "-1" "-10" "-42" "-100")
run_tests "$ROOT_DIR/wasm_32/wasm_bitselect01_32.jazz" 32 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("169680" "170520" "178080" "204960" "253680" "168840" "161280" "134400" "85680")
run_tests "$ROOT_DIR/wasm_32/wasm_max01_32.jazz" 32 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("177600" "178560" "187200" "217920" "273600" "176640" "168000" "137280" "81600")
run_tests "$ROOT_DIR/wasm_32/wasm_max02_32.jazz" 32 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("7224" "7266" "7644" "8988" "11424" "7182" "6804" "5460" "3024")
run_tests "$ROOT_DIR/wasm_32/wasm_min01_32.jazz" 32 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("-630" "-588" "-210" "1134" "3570" "-672" "-1050" "-2394" "-4830")
run_tests "$ROOT_DIR/wasm_32/wasm_min02_32.jazz" 32 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("420672" "422345" "437402" "490938" "587972" "418999" "403942" "350406" "253372")
run_tests "$ROOT_DIR/wasm_64/wasm_swizzle01_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("-4218114454" "-4011337203" "-2150341944" "4466530088" "16459610646" "-4424891705" "-6285886964" "-12902758996" "-24895839554")
run_tests "$ROOT_DIR/wasm_64/wasm_swizzle02_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("3960" "3961" "3970" "4002" "4060" "3959" "3950" "3918" "3860")
run_tests "$ROOT_DIR/wasm_64/vec_not01_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("3200" "3201" "3210" "3242" "3300" "3199" "3190" "3158" "3100")
run_tests "$ROOT_DIR/wasm_64/vec_shift01_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("301989886" "301989887" "301989896" "301989928" "301989986" "301989885" "301989876" "301989844" "301989786")
run_tests "$ROOT_DIR/wasm_64/vec_shift02_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("8623489022" "8623489023" "8623489032" "8623489064" "8623489122" "8623489021" "8623489012" "8623488980" "8623488922")
run_tests "$ROOT_DIR/wasm_64/vec_shift03_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("1656" "1657" "1666" "1698" "1756" "1655" "1646" "1614" "1556")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift01_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("1105" "1106" "1115" "1147" "1205" "1104" "1095" "1063" "1005")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift02_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("759" "760" "769" "801" "859" "758" "749" "717" "659")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift03_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("2709" "2710" "2719" "2751" "2809" "2708" "2699" "2667" "2609")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift04_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("1673" "1674" "1683" "1715" "1773" "1672" "1663" "1631" "1573")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift05_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("227754" "227755" "227764" "227796" "227854" "227753" "227744" "227712" "227654")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift06_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("7463703669" "7463703670" "7463703679" "7463703711" "7463703769" "7463703668" "7463703659" "7463703627" "7463703569")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift07_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("-1012762419210940146" "-1012762419210940145" "-1012762419210940136" "-1012762419210940104" "-1012762419210940046" "-1012762419210940147" "-1012762419210940156" "-1012762419210940188" "-1012762419210940246")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift08_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("2153" "2154" "2163" "2195" "2253" "2152" "2143" "2111" "2053")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift09_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("292778" "292779" "292788" "292820" "292878" "292777" "292768" "292736" "292678")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift10_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("11758646389" "11758646390" "11758646399" "11758646431" "11758646489" "11758646388" "11758646379" "11758646347" "11758646289")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift11_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

EXPECTED_RESULTS=("-1012762419747811058" "-1012762419747811057" "-1012762419747811048" "-1012762419747811016" "-1012762419747810958" "-1012762419747811059" "-1012762419747811068" "-1012762419747811100" "-1012762419747811158")
run_tests "$ROOT_DIR/wasm_64/wasm_vec_shift12_64.jazz" 64 "${EXPECTED_RESULTS[@]}"

# Remove build files
if [ "$CLEAN" = true ]; then
  rm -f "$WASM_32"/*.{wat,wasm}
  rm -f "$WASM_64"/*.{wat,wasm}
fi

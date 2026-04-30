#!/bin/bash


# Parse command line
usage() {
  echo "Usage: $0 [options] <nb_repeat>"
  echo "Options:"
  echo "  -a          All wasm versions considered"
  exit 1
}

NB_REPEAT=""
ALL_OPT=false

if [ "$#" -lt 1 ]; then
  usage
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -a) ALL_OPT=true; shift ;;
    -h|--help) usage ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        NB_REPEAT=$1
      else
        echo "Unkown option : $1"
        usage
      fi
      shift
      ;;
  esac
done

if [ -z "$NB_REPEAT" ]; then
    echo "Error : Repeat number <nb_repeat> is mandatory."
    usage
fi


# Globals
ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PARENT_DIR=$(dirname "$ROOT_DIR")
COMPILER_DIR=$(dirname "$PARENT_DIR")
LOG_DIR="$ROOT_DIR/logs"

COMPILER="$COMPILER_DIR/jasminc"
SEP1="########################################################################################"
SEP2="========================================================================================"
SEP3="----------------------------------------------------------------------------------------"

NAME="CHACHA20XORAVX"
name="chacha20xoravx"

VERBOSE=1
EXCLUDE_PREFIXES="Input|Result|Output|Hash|Buffer"


# Make log dir
mkdir -p "$LOG_DIR"


# Compile x86-64
ref_file="$ROOT_DIR/ref/${name}_ref.jazz"
f_c="$ROOT_DIR/main.c"

f_s="$ROOT_DIR/ref/${name}_ref.s"
f_main_o="$ROOT_DIR/ref/main_c.o"
f_o="$ROOT_DIR/ref/${name}_ref.o"
f_exe="$ROOT_DIR/ref/${name}_ref.exe"

"$COMPILER" -arch x86-64 -pasm -nowarning "$ref_file" > "$f_s"
gcc -O3 -c "$f_c" -o "$f_main_o" -lm
gcc -O3 -c "$f_s" -o "$f_o" -lm
gcc -O3 -no-pie "$f_main_o" "$f_o" -o "$f_exe" -lm


# Compile wasm with wat2wasm
f_jazz="$ROOT_DIR/prog/${name}_wasm.jazz"
f_js="$ROOT_DIR/main.js"

f_wat="$ROOT_DIR/prog/${name}_wasm.wat"
f_wasm="$ROOT_DIR/prog/${name}_wasm.wasm"

"$COMPILER" -arch wasm -pasm -nowarning "$f_jazz" > "$f_wat"


# Benchmarks
generate_string() {
  openssl rand -hex "$1"
}

extract_time() {
  echo "$1" | grep "Mean time" | grep -oE '[0-9]+\.[0-9]+'
}


run_benchmark() {
  local NB_REPEAT=$1
  local NB_ITER=$2
  local MSG=$3
  local KEY=$4
  local NONCE=$5

  local LOG_FILE="$LOG_DIR/log_verbose_${name}_${NB_REPEAT}_${NB_ITER}.txt"
  echo "$NAME" > "$LOG_FILE"

  printf "\n%s\n" "$SEP2" | tee -a "$LOG_FILE"

  res_x86=$(taskset --cpu-list 0 "$f_exe" "$NB_REPEAT" "$NB_ITER" "$MSG" "$KEY" "$NONCE" "$VERBOSE")
  time_x86=$(extract_time "$res_x86")
  printf "\nX86-64 wrapped with C :\n\n%s\n" "$res_x86" | tee -a "$LOG_FILE"


  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"


  wat2wasm "$f_wat" -o "$f_wasm"
  res_wasm_wat2wasm=$(taskset --cpu-list 0 node "$f_js" "$NB_REPEAT" "$NB_ITER" "$MSG" "$KEY" "$NONCE" "$VERBOSE")
  time_wasm_wat2wasm=$(extract_time "$res_wasm_wat2wasm")
  printf "\nWasm wrapped with JS (compiled with wat2wasm) :\n\n%s\n" "$res_wasm_wat2wasm" | tee -a "$LOG_FILE"


  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"


  if [ "$ALL_OPT" = true ]; then
    wasm-as --enable-multivalue --enable-simd "$f_wat" -o "$f_wasm"
    res_wasm_wasmas=$(taskset --cpu-list 0 node "$f_js" "$NB_REPEAT" "$NB_ITER" "$MSG" "$KEY" "$NONCE" "$VERBOSE")
    time_wasm_wasmas=$(extract_time "$res_wasm_wasmas")
    printf "\nWasm wrapped with JS (compiled with wasm-as) :\n\n%s\n" "$res_wasm_wasmas" | tee -a "$LOG_FILE"


    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  fi


  if [[ -z "$time_x86" || -z "$time_wasm_wat2wasm" || ( "$ALL_OPT" == "true" && -z "$time_wasm_wasmas" ) ]]; then
    echo "Error : Time extraction failed."
    exit 1
  fi


  if [ "$ALL_OPT" = true ]; then

    is_wat2wasm_faster=$(echo "$time_wasm_wat2wasm < $time_wasm_wasmas" | bc -l)

    if [ "$is_wat2wasm_faster" -eq 1 ]; then
      best_wasm_time=$time_wasm_wat2wasm
      best_wasm_name="wat2wasm"
      worth_wasm_name="wasm-as"
      wasm_diff=$(echo "scale=6; $time_wasm_wasmas / $time_wasm_wat2wasm" | bc -l)
    else
      best_wasm_time=$time_wasm_wasmas
      best_wasm_name="wasm-as"
      worth_wasm_name="wat2wasm"
      wasm_diff=$(echo "scale=6; $time_wasm_wat2wasm / $time_wasm_wasmas" | bc -l)
    fi
    printf "\n%s is %s times faster than %s\n" "$best_wasm_name" "$wasm_diff" "$worth_wasm_name" | tee -a "$LOG_FILE"


    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"

  else

    best_wasm_time=$time_wasm_wat2wasm
    best_wasm_name="wat2wasm"

  fi


  is_x86_faster=$(echo "$time_x86 < $best_wasm_time" | bc -l)

  if [ "$is_x86_faster" -eq 1 ]; then
    final_diff=$(echo "scale=6; $best_wasm_time / $time_x86" | bc -l)
    printf "\nX86-64 is %s times faster than Wasm (%s)\n" "$final_diff" "$best_wasm_name" | tee -a "$LOG_FILE"
  else
    final_diff=$(echo "scale=6; $time_x86 / $best_wasm_time" | bc -l)
    printf "\nWasm (%s) is %s times faster than X86-64\n" "$best_wasm_name" "$final_diff" | tee -a "$LOG_FILE"
  fi


  printf "\n%s\n" "$SEP2" | tee -a "$LOG_FILE"


  local LOG_FILE_SHORT="$LOG_DIR/log_${name}_${NB_REPEAT}_${NB_ITER}.txt"
  grep -vE "^($EXCLUDE_PREFIXES)" "$LOG_FILE" > "$LOG_FILE_SHORT"
}


printf "\n%s\n" "$SEP1"
printf "\n$NAME\n"

MSG_01="2e942a20bd194ebf04d8eb0ed40e50ef87d18c4a447dfe5cda14c7937c2e8d07"
MSG_02=$(generate_string 256)
MSG_03=$(generate_string 2048)

NONCE="070000004041424344454647"
KEY="808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"

run_benchmark $NB_REPEAT 73500000 "$MSG_01" "$NONCE" "$KEY"
run_benchmark $NB_REPEAT 19250000 "$MSG_02" "$NONCE" "$KEY"
run_benchmark $NB_REPEAT  2425000 "$MSG_03" "$NONCE" "$KEY"

printf "\n%s\n" "$SEP1"

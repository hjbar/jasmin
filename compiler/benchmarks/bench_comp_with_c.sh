#!/bin/bash

BENCH_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)


# PARSE OPTIONS
usage() {
  echo "Usage: $0 [options] <folder_name> <nb_repeat>"
  echo "Options:"
  echo "  -a          All wasm versions considered"
  exit 1
}

ALL_OPT=false
NB_REPEAT=""
TARGET_DIR=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -a) ALL_OPT=true; shift ;;
    -h|--help) usage ;;
    *)
      if [ -z "$TARGET_DIR" ] && [ -d "$BENCH_ROOT/$1" ]; then
        TARGET_DIR=$1
      elif [[ "$1" =~ ^[0-9]+$ ]]; then
        NB_REPEAT=$1
      else
        echo "Unknown option or invalid directory: $1"
        usage
      fi
      shift
      ;;
  esac
done

if [ -z "$TARGET_DIR" ] || [ -z "$NB_REPEAT" ]; then
    echo "Error: Target directory and repeat number are mandatory."
    usage
fi


# GLOBALS
ROOT_DIR="$BENCH_ROOT/$TARGET_DIR"
COMPILER_DIR=$(dirname "$BENCH_ROOT")
COMPILER="$COMPILER_DIR/jasminc"
UTILS_DIR="$BENCH_ROOT/utils"
SODIUM_JS_PATH="$HOME/dev/libs/libsodium_js/libsodium-js"
SODIUM_JS_SIMD_PATH="$HOME/dev/libs/libsodium_js_simd/libsodium-js"
#SPIDER_MONKEY="$HOME/.jsvu/bin/js"
SPIDER_MONKEY="/usr/lib/x86_64-linux-gnu/mozjs-128/js128"

if [ ! -f "$ROOT_DIR/bench.conf" ]; then
    echo "Error: Configuration file $ROOT_DIR/bench.conf not found."
    exit 1
fi
source "$ROOT_DIR/bench.conf"

LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"

LATEX_DIR="$ROOT_DIR/latex"
mkdir -p "$LATEX_DIR"

SEP1="########################################################################################"
SEP2="========================================================================================"
SEP3="----------------------------------------------------------------------------------------"
VERBOSE=1
EXCLUDE_PREFIXES="Input|Result|Output|Hash|Buffer"


# POLYFILL
f_ff_pf="$UTILS_DIR/firefox_polyfill.js"


# COMPILE C-->EXE
f_ce_c="$ROOT_DIR/c_native/${name}.c"
f_ce_exe="$ROOT_DIR/c_native/${name}.exe"

gcc -O3 "$f_ce_c" -lsodium -lm -o "$f_ce_exe"


# COMPILE C-->WASM
f_cw_c="$ROOT_DIR/c_wasm/${name}_wasm.c"
f_cw_wat_O0="$ROOT_DIR/c_wasm/${name}_wasm_O0.wat"
f_cw_wat_O2="$ROOT_DIR/c_wasm/${name}_wasm_O2.wat"
f_cw_wat_O3="$ROOT_DIR/c_wasm/${name}_wasm_O3.wat"
f_cw_wasm="$ROOT_DIR/c_wasm/${name}_wasm.wasm"
f_cw_js="$ROOT_DIR/main_emcc.js"

if [[ "$name" == *avx* ]]; then
  SODIUM_VERSION="$SODIUM_JS_SIMD_PATH"
else
  SODIUM_VERSION="$SODIUM_JS_PATH"
fi


# COMPILE JAZZ-->X86-->EXE
ref_file="$ROOT_DIR/ref/${name}_ref.jazz"
f_c="$ROOT_DIR/main.c"
f_s="$ROOT_DIR/ref/${name}_ref.s"
f_main_o="$ROOT_DIR/ref/main_c.o"
f_o="$ROOT_DIR/ref/${name}_ref.o"
f_exe="$ROOT_DIR/ref/${name}_ref.exe"

"$COMPILER" -arch x86-64 -pasm -nowarning "$ref_file" > "$f_s"
gcc -O3 -I"$UTILS_DIR" -c "$f_c" -o "$f_main_o" -lm
gcc -O3 -c "$f_s" -o "$f_o" -lm
gcc -O3 -no-pie "$f_main_o" "$f_o" -o "$f_exe" -lm


# COMPILE JAZZ-->WASM
f_jazz="$ROOT_DIR/prog/${name}_wasm.jazz"
f_js="$ROOT_DIR/main.js"
f_wat="$ROOT_DIR/prog/${name}_wasm.wat"
f_wasm="$ROOT_DIR/prog/${name}_wasm.wasm"

"$COMPILER" -arch wasm -pasm -nowarning "$f_jazz" > "$f_wat"


# BENCHMARK FUNCTIONS
generate_string() {
  openssl rand -hex "$1"
}


extract_time() {
  echo "$1" | grep "Avg per call" | grep -oE '[0-9]+\.[0-9]+'
}


run_benchmark() {
  # init locals
  local bench_note=$1
  local is_opt=$2
  local loop_repeat=$3
  local loop_iter=$4
  local loop_iter_2=$(( loop_iter + (loop_iter / 20) ))
  local loop_iter_3=$(( loop_iter - (loop_iter / 5) ))
  local loop_iter_4=$(( loop_iter - (loop_iter / 3) ))
  local algo_args=("${@:5}")

  local iter_id=${4:-"default"}
  local LOG_FILE="$LOG_DIR/log_verbose_comp_with_c_${name}_${loop_repeat}_${iter_id}.txt"
  local LATEX_FILE="$LATEX_DIR/latex_comp_with_c_${name}_${loop_repeat}_${iter_id}.txt"
  local LOG_FILE_SHORT="$LOG_DIR/log_comp_with_c_${name}_${loop_repeat}_${iter_id}.txt"


  # start log file
  echo "$NAME" > "$LOG_FILE"
  printf "\n%s\n" "$SEP2" | tee -a "$LOG_FILE"


  # COMPILE C-->EXE
  res_c_exe=$(taskset --cpu-list 0 "$f_ce_exe" "$loop_repeat" "$loop_iter_2" "${algo_args[@]}" "$VERBOSE")
  time_c_exe=$(extract_time "$res_c_exe")
  printf "\nC-->EXE :\n\n%s\n" "$res_c_exe" | tee -a "$LOG_FILE"

  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"


  # JAZZ-->X86-->EXE
  res_jazz_x86=$(taskset --cpu-list 0 "$f_exe" "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
  time_jazz_x86=$(extract_time "$res_jazz_x86")
  printf "\nJAZZ-->X86-->EXE :\n\n%s\n" "$res_jazz_x86" | tee -a "$LOG_FILE"

  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"


  # COMPILE C-->WASM

  # emcc -O0
  emcc \
    -O0 -msimd128 -msse2 -mssse3 "$f_cw_c" \
    -I"$SODIUM_VERSION"/include \
    "$SODIUM_VERSION"/lib/libsodium.a \
    -s WASM=1 \
    -s STANDALONE_WASM=1 \
    --no-entry \
    -o "$f_cw_wasm"
  wasm2wat --fold-exprs "$f_cw_wasm" -o "$f_cw_wat_O0"

  res_c_wasm=$(taskset --cpu-list 0 node --no-warnings "$f_cw_js" "$loop_repeat" "$loop_iter_3" "${algo_args[@]}" "$VERBOSE")
  time_c_wasm=$(extract_time "$res_c_wasm")
  name_c_wasm="emcc -O0 [Node]"
  printf "\nC-->WASM [using Node and emcc -O0] :\n\n%s\n" "$res_c_wasm" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"

  res_c_wasm_tmp=$(taskset --cpu-list 0 "$SPIDER_MONKEY" -f "$f_ff_pf" -f "$f_cw_js" -- "$loop_repeat" "$loop_iter_4" "${algo_args[@]}" "$VERBOSE")
  time_c_wasm_tmp=$(extract_time "$res_c_wasm_tmp")
  printf "\nC-->WASM [using Firefox and emcc -O0] :\n\n%s\n" "$res_c_wasm_tmp" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  if [ "$(echo "$time_c_wasm_tmp < $time_c_wasm" | bc -l)" -eq 1 ]; then
    time_c_wasm=$time_c_wasm_tmp
    name_c_wasm="emcc -O0 [Firefox]"
  fi

  # emcc -O2
  emcc \
    -O2 -msimd128 -msse2 -mssse3 "$f_cw_c" \
    -I"$SODIUM_VERSION"/include \
    "$SODIUM_VERSION"/lib/libsodium.a \
    -s WASM=1 \
    -s STANDALONE_WASM=1 \
    --no-entry \
    -o "$f_cw_wasm"
  wasm2wat --fold-exprs "$f_cw_wasm" -o "$f_cw_wat_O2"

  res_c_wasm_tmp=$(taskset --cpu-list 0 node --no-warnings "$f_cw_js" "$loop_repeat" "$loop_iter_3" "${algo_args[@]}" "$VERBOSE")
  time_c_wasm_tmp=$(extract_time "$res_c_wasm_tmp")
  printf "\nC-->WASM [using Node and emcc -O2] :\n\n%s\n" "$res_c_wasm_tmp" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  if [ "$(echo "$time_c_wasm_tmp < $time_c_wasm" | bc -l)" -eq 1 ]; then
    time_c_wasm=$time_c_wasm_tmp
    name_c_wasm="emcc -O2 [Node]"
  fi

  res_c_wasm_tmp=$(taskset --cpu-list 0 "$SPIDER_MONKEY" -f "$f_ff_pf" -f "$f_cw_js" -- "$loop_repeat" "$loop_iter_4" "${algo_args[@]}" "$VERBOSE")
  time_c_wasm_tmp=$(extract_time "$res_c_wasm_tmp")
  printf "\nC-->WASM [using Firefox and emcc -O2] :\n\n%s\n" "$res_c_wasm_tmp" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  if [ "$(echo "$time_c_wasm_tmp < $time_c_wasm" | bc -l)" -eq 1 ]; then
    time_c_wasm=$time_c_wasm_tmp
    name_c_wasm="emcc -O2 [Firefox]"
  fi

  # emcc -O3
  emcc \
    -O3 -msimd128 -msse2 -mssse3 "$f_cw_c" \
    -I"$SODIUM_VERSION"/include \
    "$SODIUM_VERSION"/lib/libsodium.a \
    -s WASM=1 \
    -s STANDALONE_WASM=1 \
    --no-entry \
    -o "$f_cw_wasm"
  wasm2wat --fold-exprs "$f_cw_wasm" -o "$f_cw_wat_O3"

  res_c_wasm_tmp=$(taskset --cpu-list 0 node --no-warnings "$f_cw_js" "$loop_repeat" "$loop_iter_3" "${algo_args[@]}" "$VERBOSE")
  time_c_wasm_tmp=$(extract_time "$res_c_wasm_tmp")
  printf "\nC-->WASM [using Node and emcc -O3] :\n\n%s\n" "$res_c_wasm_tmp" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  if [ "$(echo "$time_c_wasm_tmp < $time_c_wasm" | bc -l)" -eq 1 ]; then
    time_c_wasm=$time_c_wasm_tmp
    name_c_wasm="emcc -O3 [Node]"
  fi

  res_c_wasm_tmp=$(taskset --cpu-list 0 "$SPIDER_MONKEY" -f "$f_ff_pf" -f "$f_cw_js" -- "$loop_repeat" "$loop_iter_4" "${algo_args[@]}" "$VERBOSE")
  time_c_wasm_tmp=$(extract_time "$res_c_wasm_tmp")
  printf "\nC-->WASM [using Firefox and emcc -O3] :\n\n%s\n" "$res_c_wasm_tmp" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  if [ "$(echo "$time_c_wasm_tmp < $time_c_wasm" | bc -l)" -eq 1 ]; then
    time_c_wasm=$time_c_wasm_tmp
    name_c_wasm="emcc -O3 [Firefox]"
  fi


  # JAZZ-->WASM

  # wasm-as
  wasm-as --all-features "$f_wat" -o "$f_wasm"

  res_jazz_wasm=$(taskset --cpu-list 0 node --no-warnings "$f_js" "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
  time_jazz_wasm=$(extract_time "$res_jazz_wasm")
  name_jazz_wasm="wasm-as [Node]"
  printf "\nJAZZ-->WASM [using Node and wasm-as] :\n\n%s\n" "$res_jazz_wasm" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"

  res_jazz_wasm_tmp=$(taskset --cpu-list 0 "$SPIDER_MONKEY" -f "$f_ff_pf" -f "$f_js" -- "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
  time_jazz_wasm_tmp=$(extract_time "$res_jazz_wasm_tmp")
  printf "\nJAZZ-->WASM [using Firefox and wasm-as] :\n\n%s\n" "$res_jazz_wasm_tmp" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  if [ "$(echo "$time_jazz_wasm_tmp < $time_jazz_wasm" | bc -l)" -eq 1 ]; then
    time_jazz_wasm=$time_jazz_wasm_tmp
    name_jazz_wasm="wasm-as [Firefox]"
  fi

  # wasm-opt -O3
  wasm-opt -O3 --all-features "$f_wat" -o "$f_wasm"

  res_jazz_wasm_tmp=$(taskset --cpu-list 0 node --no-warnings "$f_js" "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
  time_jazz_wasm_tmp=$(extract_time "$res_jazz_wasm_tmp")
  printf "\nJAZZ-->WASM [using Node and wasm-opt -O3] :\n\n%s\n" "$res_jazz_wasm_tmp" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  if [ "$(echo "$time_jazz_wasm_tmp < $time_jazz_wasm" | bc -l)" -eq 1 ]; then
    time_jazz_wasm=$time_jazz_wasm_tmp
    name_jazz_wasm="wasm-opt -O3 [Node]"
  fi

  res_jazz_wasm_tmp=$(taskset --cpu-list 0 "$SPIDER_MONKEY" -f "$f_ff_pf" -f "$f_js" -- "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
  time_jazz_wasm_tmp=$(extract_time "$res_jazz_wasm_tmp")
  printf "\nJAZZ-->WASM [using Firefox and wasm-opt -O3] :\n\n%s\n" "$res_jazz_wasm_tmp" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  if [ "$(echo "$time_jazz_wasm_tmp < $time_jazz_wasm" | bc -l)" -eq 1 ]; then
    time_jazz_wasm=$time_jazz_wasm_tmp
    name_jazz_wasm="wasm-opt -O3 [Firefox]"
  fi

  # wasm-opt -O4
  wasm-opt -O4 --all-features "$f_wat" -o "$f_wasm"

  res_jazz_wasm_tmp=$(taskset --cpu-list 0 node --no-warnings "$f_js" "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
  time_jazz_wasm_tmp=$(extract_time "$res_jazz_wasm_tmp")
  printf "\nJAZZ-->WASM [using Node and wasm-opt -O4] :\n\n%s\n" "$res_jazz_wasm_tmp" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  if [ "$(echo "$time_jazz_wasm_tmp < $time_jazz_wasm" | bc -l)" -eq 1 ]; then
    time_jazz_wasm=$time_jazz_wasm_tmp
    name_jazz_wasm="wasm-opt -O4 [Node]"
  fi

  res_jazz_wasm_tmp=$(taskset --cpu-list 0 "$SPIDER_MONKEY" -f "$f_ff_pf" -f "$f_js" -- "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
  time_jazz_wasm_tmp=$(extract_time "$res_jazz_wasm_tmp")
  printf "\nJAZZ-->WASM [using Firefox and wasm-opt -O4] :\n\n%s\n" "$res_jazz_wasm_tmp" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  if [ "$(echo "$time_jazz_wasm_tmp < $time_jazz_wasm" | bc -l)" -eq 1 ]; then
    time_jazz_wasm=$time_jazz_wasm_tmp
    name_jazz_wasm="wasm-opt -O4 [Firefox]"
  fi


  # results
  diff_native=$(echo "scale=6; $time_c_exe / $time_jazz_x86" | bc -l)
  LC_NUMERIC=C printf "\nRatio between C-->EXE and JAZZ-->X86-->EXE : %.6f\n" "$diff_native" | tee -a "$LOG_FILE"

  diff_wasm=$(echo "scale=6; $time_c_wasm / $time_jazz_wasm" | bc -l)
  LC_NUMERIC=C printf "\nRatio between C-->WASM (%s) and JAZZ-->WASM (%s) : %.6f\n" "$name_c_wasm" "$name_jazz_wasm" "$diff_wasm" | tee -a "$LOG_FILE"

  final_diff=$(echo "scale=6; $diff_wasm / $diff_native" | bc -l)
  LC_NUMERIC=C printf "\nRatio between WASM and native : %.6f\n" "$final_diff" | tee -a "$LOG_FILE"


  # summary
  printf "\n%s\n%s\n" "$SEP3" "$SEP3" | tee -a "$LOG_FILE"

  # C-->EXE
  LC_NUMERIC=C printf "\nC-->EXE : %.6f\n" "$time_c_exe" | tee -a "$LOG_FILE"

  # JAZZ-->X86-->EXE
  LC_NUMERIC=C printf "\nJAZZ-->X86-->EXE : %.6f\n" "$time_jazz_x86" | tee -a "$LOG_FILE"

  # C-->WASM
  LC_NUMERIC=C printf "\nC-->WASM (%s) : %.6f\n" "$name_c_wasm" "$time_c_wasm" | tee -a "$LOG_FILE"

  # JAZZ-->WASM
  LC_NUMERIC=C printf "\nJAZZ-->WASM (%s) : %.6f\n" "$name_jazz_wasm" "$time_jazz_wasm" | tee -a "$LOG_FILE"

  # All
  LC_NUMERIC=C printf "\nC-->EXE / JAZZ-->X86-->EXE : %.6f\n" "$diff_native" | tee -a "$LOG_FILE"
  LC_NUMERIC=C printf "\nC-->WASM (%s) / JAZZ-->WASM (%s) : %.6f\n" "$name_c_wasm" "$name_jazz_wasm" "$diff_wasm" | tee -a "$LOG_FILE"
  LC_NUMERIC=C printf "\nWASM / EXE : %.6f\n" "$final_diff" | tee -a "$LOG_FILE"

  # Latex
  LC_NUMERIC=C printf "%s (%s);%s;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f\n" \
                      "$name" "$bench_note" "$is_opt" \
                      "$time_c_exe" \
                      "$time_jazz_x86" \
                      "$time_c_wasm" \
                      "$time_jazz_wasm" \
                      "$diff_native" "$diff_wasm" "$final_diff" \
                      > "$LATEX_FILE"


  # end log file
  printf "\n%s\n" "$SEP2" | tee -a "$LOG_FILE"


  # make short log file
  grep -vE "^($EXCLUDE_PREFIXES)" "$LOG_FILE" > "$LOG_FILE_SHORT"
}


# MAIN
printf "\n%s\n\n%s\n" "$SEP1" "$NAME"
run_algorithm_tests "$NB_REPEAT"
printf "\n%s\n" "$SEP1"

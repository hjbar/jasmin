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
CLANG="$HOME/dev/libs/emsdk/upstream/bin/clang"
WASMAS="$HOME/dev/libs/emsdk/upstream/bin/wasm-as"
WASMOPT="$HOME/dev/libs/emsdk/upstream/bin/wasm-opt"
WASMTIME="$HOME/dev/libs/wasmtime/artifacts"
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
f_ce_c="$ROOT_DIR/c_wasmtime/${name}.c"
f_ce_exe="$ROOT_DIR/c_wasmtime/${name}.exe"

"$CLANG" \
  -O3 "$f_ce_c" \
  -I"$WASMTIME"/include \
  -L"$WASMTIME"/lib \
  -Wl,-rpath,"$WASMTIME"/lib \
  -lwasmtime -lm -lpthread -ldl \
  -o "$f_ce_exe"


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
  local algo_args=("${@:5}")

  local iter_id=${4:-"default"}
  local LOG_FILE="$LOG_DIR/log_verbose_comp_with_wasmtime_${name}_${loop_repeat}_${iter_id}.txt"
  local LATEX_FILE="$LATEX_DIR/latex_comp_with_wasmtime_${name}_${loop_repeat}_${iter_id}.txt"
  local LOG_FILE_SHORT="$LOG_DIR/log_comp_with_wasmtime_${name}_${loop_repeat}_${iter_id}.txt"


  # start log file
  echo "$NAME" > "$LOG_FILE"
  printf "\n%s\n" "$SEP2" | tee -a "$LOG_FILE"


  # WASM-AS
  "$WASMAS" --all-features "$f_wat" -o "$f_wasm"

  # node/v8 + firefox/spidermonkey
  res_jazz_wasm=$(taskset --cpu-list 0 node --no-warnings "$f_js" "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
  time_jazz_wasm=$(extract_time "$res_jazz_wasm")
  name_jazz_wasm="wasm-as [Node]"
  printf "\nJAZZ-->WASM [using Node and wasm-as] :\n\n%s\n" "$res_jazz_wasm" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"

  if [ "$ALL_OPT" = true ]; then
    res_jazz_wasm_tmp=$(taskset --cpu-list 0 "$SPIDER_MONKEY" -f "$f_ff_pf" -f "$f_js" -- "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
    time_jazz_wasm_tmp=$(extract_time "$res_jazz_wasm_tmp")
    printf "\nJAZZ-->WASM [using Firefox and wasm-as] :\n\n%s\n" "$res_jazz_wasm_tmp" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
    if [ "$(echo "$time_jazz_wasm_tmp < $time_jazz_wasm" | bc -l)" -eq 1 ]; then
      time_jazz_wasm=$time_jazz_wasm_tmp
      name_jazz_wasm="wasm-as [Firefox]"
    fi
  fi

  # wasmtime
  res_c_wasmtime=$(taskset --cpu-list 0 "$f_ce_exe" "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
  time_c_wasmtime=$(extract_time "$res_c_wasmtime")
  name_c_wasmtime="wasm-as [Wasmtime]"
  printf "\nJAZZ-->WASM [using Wasmtime and wasm-as] : \n\n%s\n" "$res_c_wasmtime" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"


  # WASM-OPT -O3
  if [ "$ALL_OPT" = true ]; then
    "$WASMOPT" -O3 --all-features "$f_wat" -o "$f_wasm"

    # node/v8 + firefox/spidermonkey
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

    # wasmtime
    res_c_wasmtime_tmp=$(taskset --cpu-list 0 "$f_ce_exe" "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
    time_c_wasmtime_tmp=$(extract_time "$res_c_wasmtime_tmp")
    printf "\nJAZZ-->WASM [using Wasmtime and wasm-opt -O3] : \n\n%s\n" "$res_c_wasmtime_tmp" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
    if [ "$(echo "$time_c_wasmtime_tmp < $time_c_wasmtime" | bc -l)" -eq 1 ]; then
      time_c_wasmtime=$time_c_wasmtime_tmp
      name_c_wasmtime="wasm-opt -O3 [Wasmtime]"
    fi
  fi


  # WASM-OPT -O4
  if [ "$ALL_OPT" = true ]; then
    "$WASMOPT" -O4 --all-features "$f_wat" -o "$f_wasm"

    # node/v8 + firefox/spidermonkey
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

    # wasmtime
    res_c_wasmtime_tmp=$(taskset --cpu-list 0 "$f_ce_exe" "$loop_repeat" "$loop_iter" "${algo_args[@]}" "$VERBOSE")
    time_c_wasmtime_tmp=$(extract_time "$res_c_wasmtime_tmp")
    printf "\nJAZZ-->WASM [using Wasmtime and wasm-opt -O4] : \n\n%s\n" "$res_c_wasmtime_tmp" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
    if [ "$(echo "$time_c_wasmtime_tmp < $time_c_wasmtime" | bc -l)" -eq 1 ]; then
      time_c_wasmtime=$time_c_wasmtime_tmp
      name_c_wasmtime="wasm-opt -O4 [Wasmtime]"
    fi
  fi


  # results
  final_diff=$(echo "scale=6; $time_c_wasmtime / $time_jazz_wasm" | bc -l)
  LC_NUMERIC=C printf "\nRatio between WASMTIME and NODE+FIREFOX : %.6f\n" "$final_diff" | tee -a "$LOG_FILE"


  # summary
  printf "\n%s\n%s\n" "$SEP3" "$SEP3" | tee -a "$LOG_FILE"

  # NODE/V8 + FIREFOX/SPIDERMONKEY
  LC_NUMERIC=C printf "\nNode/V8 + Firefox/SpiderMonkey (%s) : %.6f\n" "$name_jazz_wasm" "$time_jazz_wasm" | tee -a "$LOG_FILE"

  # WASMTIME
  LC_NUMERIC=C printf "\nWasmtime/Cranelift (%s) : %.6f\n" "$name_c_wasmtime" "$time_c_wasmtime" | tee -a "$LOG_FILE"

  # ALL
  LC_NUMERIC=C printf "\nWASMTIME (%s) / NODE+FIREFOX (%s) : %.6f\n" "$name_c_wasmtime" "$name_jazz_wasm" "$final_diff" | tee -a "$LOG_FILE"

  # Latex
  LC_NUMERIC=C printf "%s (%s);%s;%.6f;%.6f;%.6f\n" \
                      "$name" "$bench_note" "$is_opt" \
                      "$time_jazz_wasm" \
                      "$time_c_wasmtime" \
                      "$final_diff" \
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

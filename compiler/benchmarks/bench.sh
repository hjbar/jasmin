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


# COMPILE X86-64
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


# COMPILE WASM
f_ff_pf="$UTILS_DIR/firefox_polyfill.js"
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
  echo "$1" | grep "Mean time" | grep -oE '[0-9]+\.[0-9]+'
}

run_benchmark() {
  # init locals
  local bench_note=$1
  local is_opt=$2
  local loop_repeat=$3
  local algo_args=("${@:4}")

  local iter_id=${4:-"default"}
  local LOG_FILE="$LOG_DIR/log_verbose_${name}_${loop_repeat}_${iter_id}.txt"
  local LATEX_FILE="$LATEX_DIR/latex_${name}_${loop_repeat}_${iter_id}.txt"


  # start log file
  echo "$NAME" > "$LOG_FILE"
  printf "\n%s\n" "$SEP2" | tee -a "$LOG_FILE"


  # x86-64
  res_x86=$(taskset --cpu-list 0 "$f_exe" "$loop_repeat" "${algo_args[@]}" "$VERBOSE")
  time_x86=$(extract_time "$res_x86")
  printf "\nX86-64 wrapped with C :\n\n%s\n" "$res_x86" | tee -a "$LOG_FILE"

  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"


  # wasm-as
  if [ "$ALL_OPT" = true ]; then
    wasm-as --all-features "$f_wat" -o "$f_wasm"

    res_wasm_wasmas=$(taskset --cpu-list 0 node "$f_js" "$loop_repeat" "${algo_args[@]}" "$VERBOSE")
    time_wasm_wasmas=$(extract_time "$res_wasm_wasmas")
    printf "\nWasm wrapped with JS [using Node] (compiled with wasm-as) :\n\n%s\n" "$res_wasm_wasmas" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"

    res_wasm_wasmas_firefox=$(taskset --cpu-list 0 "$SPIDER_MONKEY" -f "$f_ff_pf" -f "$f_js" -- "$loop_repeat" "${algo_args[@]}" "$VERBOSE")
    time_wasm_wasmas_firefox=$(extract_time "$res_wasm_wasmas_firefox")
    printf "\nWasm wrapped with JS [using Firefox] (compiled with wasm-as) :\n\n%s\n" "$res_wasm_wasmas_firefox" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  fi

  # wasm-opt -O3
  wasm-opt -O3 --all-features "$f_wat" -o "$f_wasm"

  res_wasm_wasmopt3=$(taskset --cpu-list 0 node "$f_js" "$loop_repeat" "${algo_args[@]}" "$VERBOSE")
  time_wasm_wasmopt3=$(extract_time "$res_wasm_wasmopt3")
  printf "\nWasm wrapped with JS [using Node] (compiled with wasm-opt -O3) :\n\n%s\n" "$res_wasm_wasmopt3" | tee -a "$LOG_FILE"
  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"

  if [ "$ALL_OPT" = true ]; then
    res_wasm_wasmopt3_firefox=$(taskset --cpu-list 0 "$SPIDER_MONKEY" -f "$f_ff_pf" -f "$f_js" -- "$loop_repeat" "${algo_args[@]}" "$VERBOSE")
    time_wasm_wasmopt3_firefox=$(extract_time "$res_wasm_wasmopt3_firefox")
    printf "\nWasm wrapped with JS [using Firefox] (compiled with wasm-opt -O3) :\n\n%s\n" "$res_wasm_wasmopt3_firefox" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  fi


  # wasm-opt -O4
  if [ "$ALL_OPT" = true ]; then
    wasm-opt -O4 --all-features "$f_wat" -o "$f_wasm"

    res_wasm_wasmopt4=$(taskset --cpu-list 0 node "$f_js" "$loop_repeat" "${algo_args[@]}" "$VERBOSE")
    time_wasm_wasmopt4=$(extract_time "$res_wasm_wasmopt4")
    printf "\nWasm wrapped with JS [using Node] (compiled with wasm-opt -O4) :\n\n%s\n" "$res_wasm_wasmopt4" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"

    res_wasm_wasmopt4_firefox=$(taskset --cpu-list 0 "$SPIDER_MONKEY" -f "$f_ff_pf" -f "$f_js" -- "$loop_repeat" "${algo_args[@]}" "$VERBOSE")
    time_wasm_wasmopt4_firefox=$(extract_time "$res_wasm_wasmopt4_firefox")
    printf "\nWasm wrapped with JS [using Firefox] (compiled with wasm-opt -O4) :\n\n%s\n" "$res_wasm_wasmopt4_firefox" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  fi


  # save the best wasm-opt between O3 and O4 with Node
  if [ "$ALL_OPT" = true ]; then
    if [ "$(echo "$time_wasm_wasmopt3 < $time_wasm_wasmopt4" | bc -l)" -eq 1 ]; then
      time_wasm_wasmopt=$time_wasm_wasmopt3
      name_wasm_wasmopt="wasm-opt -O3 [Node]"
    else
      time_wasm_wasmopt=$time_wasm_wasmopt4
      name_wasm_wasmopt="wasm-opt -O4 [Node]"
    fi
    wasmopt_diff=$(echo "scale=6; $time_wasm_wasmopt3 / $time_wasm_wasmopt4" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-opt -O3 [Node] and wasm-opt -O4 [Node] : %.6f\n" "$wasmopt_diff" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  else
    time_wasm_wasmopt=$time_wasm_wasmopt3
    name_wasm_wasmopt="wasm-opt -O3 [Node]"
  fi


  # save the best wasm-opt between O3 and O4 with Firefox
  if [ "$ALL_OPT" = true ]; then
    if [ "$(echo "$time_wasm_wasmopt3_firefox < $time_wasm_wasmopt4_firefox" | bc -l)" -eq 1 ]; then
      time_wasm_wasmopt_firefox=$time_wasm_wasmopt3_firefox
      name_wasm_wasmopt_firefox="wasm-opt -O3 [Firefox]"
    else
      time_wasm_wasmopt_firefox=$time_wasm_wasmopt4_firefox
      name_wasm_wasmopt_firefox="wasm-opt -O4 [Firefox]"
    fi
    wasmopt_diff_firefox=$(echo "scale=6; $time_wasm_wasmopt3_firefox / $time_wasm_wasmopt4_firefox" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-opt -O3 [Firefox] and wasm-opt -O4 [Firefox] : %.6f\n" "$wasmopt_diff_firefox" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  fi


  # results
  if [[ -z "$time_x86" || -z "$time_wasm_wasmopt" || ( "$ALL_OPT" == "true" && -z "$time_wasm_wasmas" ) || ( "$ALL_OPT" == "true" && -z "$time_wasm_wasmopt_firefox" ) || ( "$ALL_OPT" == "true" && -z "$time_wasm_wasmas_firefox" ) ]]; then
    echo "Error : Time extraction failed."
    exit 1
  fi

  if [ "$ALL_OPT" = true ]; then
    if [ "$(echo "$time_wasm_wasmopt < $time_wasm_wasmas" | bc -l)" -eq 1 ]; then
      best_wasm_time=$time_wasm_wasmopt
      best_wasm_name="$name_wasm_wasmopt"
    else
      best_wasm_time=$time_wasm_wasmas
      best_wasm_name="wasm-as [Node]"
    fi
    wasm_diff=$(echo "scale=6; $time_wasm_wasmas / $time_wasm_wasmopt" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-as [Node] and %s : %.6f\n" "$name_wasm_wasmopt" "$wasm_diff" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"

    if [ "$(echo "$time_wasm_wasmopt_firefox < $time_wasm_wasmas_firefox" | bc -l)" -eq 1 ]; then
      best_wasm_time_firefox=$time_wasm_wasmopt_firefox
      best_wasm_name_firefox="$name_wasm_wasmopt_firefox"
    else
      best_wasm_time_firefox=$time_wasm_wasmas_firefox
      best_wasm_name_firefox="wasm-as [Firefox]"
    fi
    wasm_diff_firefox=$(echo "scale=6; $time_wasm_wasmas_firefox / $time_wasm_wasmopt_firefox" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-as [Firefox] and %s : %.6f\n" "$name_wasm_wasmopt_firefox" "$wasm_diff_firefox" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  else
    best_wasm_time=$time_wasm_wasmopt
    best_wasm_name="$name_wasm_wasmopt"
  fi

  if [ "$ALL_OPT" = true ]; then
    if [ "$(echo "$best_wasm_time < $best_wasm_time_firefox" | bc -l)" -eq 1 ]; then
      best_wasm_time_all=$best_wasm_time
      best_wasm_name_all=$best_wasm_name
    else
      best_wasm_time_all=$best_wasm_time_firefox
      best_wasm_name_all=$best_wasm_name_firefox
    fi
    wasm_diff_all=$(echo "scale=6; $best_wasm_time / $best_wasm_time_firefox" | bc -l)
    LC_NUMERIC=C printf "\nRatio between best-Wasm (%s) and best-Wasm (%s) : %.6f\n" "$best_wasm_name" "$best_wasm_name_firefox" "$wasm_diff_all" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  else
    best_wasm_time_all=$best_wasm_time
    best_wasm_name_all=$best_wasm_name
  fi

  final_diff=$(echo "scale=6; $best_wasm_time_all / $time_x86" | bc -l)
  LC_NUMERIC=C printf "\nRatio between Wasm (%s) and X86-64 : %.6f\n" "$best_wasm_name_all" "$final_diff" | tee -a "$LOG_FILE"


  # summary
  if [ "$ALL_OPT" = true ]; then
    printf "\n%s\n%s\n" "$SEP3" "$SEP3" | tee -a "$LOG_FILE"

    # Node
    LC_NUMERIC=C printf "\nRatio between wasm-opt -O3 [Node] and wasm-opt -O4 [Node] : %.6f\n" "$wasmopt_diff" | tee -a "$LOG_FILE"

    LC_NUMERIC=C printf "\nRatio between wasm-as [Node] and best-wasm-opt [Node] : %.6f\n" "$wasm_diff" | tee -a "$LOG_FILE"

    wasmas_x86_diff=$(echo "scale=6; $time_wasm_wasmas / $time_x86" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-as [Node] and X86-64 : %.6f\n" "$wasmas_x86_diff" | tee -a "$LOG_FILE"

    wasmopt3_x86_diff=$(echo "scale=6; $time_wasm_wasmopt3 / $time_x86" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-opt -O3 [Node] and X86-64 : %.6f\n" "$wasmopt3_x86_diff" | tee -a "$LOG_FILE"

    wasmopt4_x86_diff=$(echo "scale=6; $time_wasm_wasmopt4 / $time_x86" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-opt -O4 [Node] and X86-64 : %.6f\n" "$wasmopt4_x86_diff" | tee -a "$LOG_FILE"

    wasmbest_x86_diff=$(echo "scale=6; $best_wasm_time / $time_x86" | bc -l)
    LC_NUMERIC=C printf "\nRatio between best-Wasm [Node] and X86-64 : %.6f\n" "$wasmbest_x86_diff" | tee -a "$LOG_FILE"

    # Firefox
    LC_NUMERIC=C printf "\nRatio between wasm-opt -O3 [Firefox] and wasm-opt -O4 [Firefox] : %.6f\n" "$wasmopt_diff_firefox" | tee -a "$LOG_FILE"

    LC_NUMERIC=C printf "\nRatio between wasm-as [Firefox] and best-wasm-opt [Firefox] : %.6f\n" "$wasm_diff_firefox" | tee -a "$LOG_FILE"

    wasmas_x86_diff_firefox=$(echo "scale=6; $time_wasm_wasmas_firefox / $time_x86" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-as [Firefox] and X86-64 : %.6f\n" "$wasmas_x86_diff_firefox" | tee -a "$LOG_FILE"

    wasmopt3_x86_diff_firefox=$(echo "scale=6; $time_wasm_wasmopt3_firefox / $time_x86" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-opt -O3 [Firefox] and X86-64 : %.6f\n" "$wasmopt3_x86_diff_firefox" | tee -a "$LOG_FILE"

    wasmopt4_x86_diff_firefox=$(echo "scale=6; $time_wasm_wasmopt4_firefox / $time_x86" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-opt -O4 [Firefox] and X86-64 : %.6f\n" "$wasmopt4_x86_diff_firefox" | tee -a "$LOG_FILE"

    wasmbest_x86_diff_firefox=$(echo "scale=6; $best_wasm_time_firefox / $time_x86" | bc -l)
    LC_NUMERIC=C printf "\nRatio between best-Wasm [Firefox] and X86-64 : %.6f\n" "$wasmbest_x86_diff_firefox" | tee -a "$LOG_FILE"

    # All
    wasm_wasmas_all_diff=$(echo "scale=6; $time_wasm_wasmas / $time_wasm_wasmas_firefox" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-as [Node] and wasm-as [Firefox] : %.6f\n" "$wasm_wasmas_all_diff" | tee -a "$LOG_FILE"

    wasm_wasmopt3_all_diff=$(echo "scale=6; $time_wasm_wasmopt3 / $time_wasm_wasmopt3_firefox" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-opt -O3 [Node] and wasm-opt -O4 [Firefox] : %.6f\n" "$wasm_wasmopt3_all_diff" | tee -a "$LOG_FILE"

    wasm_wasmopt4_all_diff=$(echo "scale=6; $time_wasm_wasmopt4 / $time_wasm_wasmopt4_firefox" | bc -l)
    LC_NUMERIC=C printf "\nRatio between wasm-opt -O4 [Node] and wasm-opt -O4 [Firefox] : %.6f\n" "$wasm_wasmopt4_all_diff" | tee -a "$LOG_FILE"

    LC_NUMERIC=C printf "\nRatio between best-Wasm [Node] and best-Wasm [Firefox] : %.6f\n" "$wasm_diff_all" | tee -a "$LOG_FILE"

    LC_NUMERIC=C printf "\nRatio between best-Wasm [All] and X86-64 : %.6f\n" "$final_diff" | tee -a "$LOG_FILE"

    # Latex
    LC_NUMERIC=C printf "%s (%s);%s;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f\n" \
                        "$name" "$bench_note" "$is_opt" \
                        "$wasmopt_diff" "$wasm_diff" "$wasmas_x86_diff" "$wasmopt3_x86_diff" "$wasmopt4_x86_diff" "$wasmbest_x86_diff" \
                        "$wasmopt_diff_firefox" "$wasm_diff_firefox" "$wasmas_x86_diff_firefox" "$wasmopt3_x86_diff_firefox" "$wasmopt4_x86_diff_firefox" "$wasmbest_x86_diff_firefox" \
                        "$wasm_wasmas_all_diff" "$wasm_wasmopt3_all_diff" "$wasm_wasmopt4_all_diff" "$wasm_diff_all" "$final_diff" \
                        > "$LATEX_FILE"
  fi


  # end log file
  printf "\n%s\n" "$SEP2" | tee -a "$LOG_FILE"


  # make short log file
  local LOG_FILE_SHORT="$LOG_DIR/log_${name}_${loop_repeat}_${iter_id}.txt"
  grep -vE "^($EXCLUDE_PREFIXES)" "$LOG_FILE" > "$LOG_FILE_SHORT"
}


# MAIN
printf "\n%s\n\n%s\n" "$SEP1" "$NAME"
run_algorithm_tests "$NB_REPEAT"
printf "\n%s\n" "$SEP1"

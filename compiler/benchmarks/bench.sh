#!/bin/bash


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
      if [ -z "$TARGET_DIR" ] && [ -d "$1" ]; then
        TARGET_DIR=$(cd "$1" && pwd)
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
ROOT_DIR="$TARGET_DIR"
BENCH_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
COMPILER_DIR=$(dirname "$BENCH_ROOT")
COMPILER="$COMPILER_DIR/jasminc"

if [ ! -f "$ROOT_DIR/bench.conf" ]; then
    echo "Error: Configuration file $ROOT_DIR/bench.conf not found."
    exit 1
fi
source "$ROOT_DIR/bench.conf"

LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"

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
gcc -O3 -c "$f_c" -o "$f_main_o" -lm
gcc -O3 -c "$f_s" -o "$f_o" -lm
gcc -O3 -no-pie "$f_main_o" "$f_o" -o "$f_exe" -lm


# COMPILE WASM
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
  local loop_repeat=$1
  local algo_args=("${@:2}")

  local iter_id=${2:-"default"}
  local LOG_FILE="$LOG_DIR/log_verbose_${name}_${loop_repeat}_${iter_id}.txt"


  # start log file
  echo "$NAME" > "$LOG_FILE"
  printf "\n%s\n" "$SEP2" | tee -a "$LOG_FILE"


  # x86-64
  res_x86=$(taskset --cpu-list 0 "$f_exe" "$loop_repeat" "${algo_args[@]}" "$VERBOSE")
  time_x86=$(extract_time "$res_x86")
  printf "\nX86-64 wrapped with C :\n\n%s\n" "$res_x86" | tee -a "$LOG_FILE"

  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"


  # wat2wasm
  wat2wasm "$f_wat" -o "$f_wasm"
  res_wasm_wat2wasm=$(taskset --cpu-list 0 node "$f_js" "$loop_repeat" "${algo_args[@]}" "$VERBOSE")
  time_wasm_wat2wasm=$(extract_time "$res_wasm_wat2wasm")
  printf "\nWasm wrapped with JS (compiled with wat2wasm) :\n\n%s\n" "$res_wasm_wat2wasm" | tee -a "$LOG_FILE"

  printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"


  # wasm-as
  if [ "$ALL_OPT" = true ]; then
    wasm-as --all-features "$f_wat" -o "$f_wasm"
    res_wasm_wasmas=$(taskset --cpu-list 0 node "$f_js" "$loop_repeat" "${algo_args[@]}" "$VERBOSE")
    time_wasm_wasmas=$(extract_time "$res_wasm_wasmas")
    printf "\nWasm wrapped with JS (compiled with wasm-as) :\n\n%s\n" "$res_wasm_wasmas" | tee -a "$LOG_FILE"
    printf "\n%s\n" "$SEP3" | tee -a "$LOG_FILE"
  fi


  # results
  if [[ -z "$time_x86" || -z "$time_wasm_wat2wasm" || ( "$ALL_OPT" == "true" && -z "$time_wasm_wasmas" ) ]]; then
    echo "Error : Time extraction failed."
    exit 1
  fi

  if [ "$ALL_OPT" = true ]; then
    if [ "$(echo "$time_wasm_wat2wasm < $time_wasm_wasmas" | bc -l)" -eq 1 ]; then
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

  if [ "$(echo "$time_x86 < $best_wasm_time" | bc -l)" -eq 1 ]; then
    final_diff=$(echo "scale=6; $best_wasm_time / $time_x86" | bc -l)
    printf "\nX86-64 is %s times faster than Wasm (%s)\n" "$final_diff" "$best_wasm_name" | tee -a "$LOG_FILE"
  else
    final_diff=$(echo "scale=6; $time_x86 / $best_wasm_time" | bc -l)
    printf "\nWasm (%s) is %s times faster than X86-64\n" "$best_wasm_name" "$final_diff" | tee -a "$LOG_FILE"
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

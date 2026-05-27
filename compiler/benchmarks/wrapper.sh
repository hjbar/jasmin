#!/bin/bash


# Parse command line
usage() {
  echo "Usage: $0 [options] <nb_repeat>"
  echo "Options:"
  echo "  --rm-logs   Remove all the sub-logs (without compute benchmarks)"
  echo "  --mk-logs   Generate only the global-log (without compute benchmarks)"
  echo "  --all       All wasm versions considered"
  exit 1
}

NB_REPEAT=""
RM_LOGS=false
MK_LOGS=false
ALL=false

if [ "$#" -lt 1 ]; then
  usage
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --rm-logs) RM_LOGS=true; shift ;;
    --mk-logs) MK_LOGS=true; shift ;;
    --all)     ALL=true;     shift ;;
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
COMPILER_DIR=$(dirname "$ROOT_DIR")
LOG_DIR="$ROOT_DIR/logs"

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

SCRIPTS=(
  "$GIMLI"
  "$SHA256"         "$SHA256_OPT"
  "$CHACHA20"       "$CHACHA20_OPT"
  "$CHACHA20AVX"    "$CHACHA20AVX_OPT"
  "$CHACHA20XOR"    "$CHACHA20XOR_OPT"
  "$CHACHA20XORAVX" "$CHACHA20XORAVX_OPT"
)

LOG_NAME="log_verbose_${NB_REPEAT}.txt"
LOG_FILE="$LOG_DIR/$LOG_NAME"

LOG_NAME_SHORT="log_${NB_REPEAT}.txt"
LOG_FILE_SHORT="$LOG_DIR/$LOG_NAME_SHORT"

SEP1="########################################################################################"
SEP2="========================================================================================"
SEP3="----------------------------------------------------------------------------------------"


# Benchmark script
bench() {
  # Compile Jasminc
  echo "Build..."
  make -C "$COMPILER_DIR"
  clear

  # Make sub-log dirs
  for folder in "${SCRIPTS[@]}"; do
    mkdir -p "$folder/logs"
  done

  # Run scripts
  for folder in "${SCRIPTS[@]}"; do
    if [ "$ALL" = true ]; then
      bash bench.sh -a $folder $NB_REPEAT
    else
      bash bench.sh $folder $NB_REPEAT
    fi
  done
}


# Remove logs
remove_logs() {
  for folder in "${SCRIPTS[@]}"; do
    rm -rf "$folder/logs/log_verbose_"*"_${NB_REPEAT}_"*.txt
    rm -rf "$folder/logs/log_"*"_${NB_REPEAT}_"*.txt
  done

  rm -rf "$LOG_FILE"
  rm -rf "$LOG_FILE_SHORT"
}


# Make logs
make_logs() {
  # Make the log dir
  mkdir -p "$LOG_DIR"

  # Make the global log
  echo "" > "$LOG_FILE"
  echo "" > "$LOG_FILE_SHORT"

  for folder in "${SCRIPTS[@]}"; do

    SEARCH="log_verbose_*_${NB_REPEAT}_*.txt"
    find "$folder/logs" -type f -name "$SEARCH" | sort | while read -r current_log; do
      {
        echo ""
        echo "$SEP1"
        echo ""
        cat "$current_log"
        echo ""
        echo "$SEP1"
        echo ""
      } >> "$LOG_FILE"
    done

    SEARCH_SHORT="log_*_${NB_REPEAT}_*.txt"
    find "$folder/logs" -type f -name "$SEARCH_SHORT" ! -name "$SEARCH" | sort | while read -r current_log; do
      {
        echo ""
        echo "$SEP1"
        echo ""
        cat "$current_log"
        echo ""
        echo "$SEP1"
        echo ""
      } >> "$LOG_FILE_SHORT"
    done

  done
}


# Main script
if [ "$RM_LOGS" = true ]; then
  remove_logs
elif [ "$MK_LOGS" = true ]; then
  make_logs
else
  bench
  make_logs
fi

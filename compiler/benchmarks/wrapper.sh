#!/bin/bash


# Parse command line
usage() {
  echo "Usage: $0 [options] <nb_repeat>"
  echo "Options:"
  echo "  --rm-logs   Remove all the sub-logs (without compute benchmarks)"
  echo "  --mk-logs   Generate only the global-log (without compute benchmarks)"
  echo "  --rm-latex  Remove all the sub-latex (without compute benchmarks)"
  echo "  --mk-latex  Generate only the global-latex (without compute benchmarks)"
  echo "  --all       All wasm versions considered"
  exit 1
}

NB_REPEAT=""
RM_LOGS=false
MK_LOGS=false
RM_LATEX=false
MK_LATEX=false
ALL=false

if [ "$#" -lt 1 ]; then
  usage
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --rm-logs)  RM_LOGS=true; shift ;;
    --mk-logs)  MK_LOGS=true; shift ;;
    --rm-latex) RM_LATEX=true; shift ;;
    --mk-latex) MK_LATEX=true; shift ;;
    --all)      ALL=true;     shift ;;
    -h|--help)  usage ;;
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
LATEX_DIR="$ROOT_DIR/latex"

GIMLI="gimli"

SHA256="sha256"
SHA256_OPT="sha256-opt"

CHACHA20="chacha20"
CHACHA20_OPT="chacha20-opt"

CHACHA20AVX="chacha20avx"
CHACHA20AVX_OPT="chacha20avx-opt"

CHACHA20XOR="chacha20xor"
CHACHA20XOR_OPT="chacha20xor-opt"

CHACHA20XORAVX="chacha20xoravx"
CHACHA20XORAVX_OPT="chacha20xoravx-opt"

DIRNAMES=(
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

LATEX_NAME="latex_${NB_REPEAT}.txt"
LATEX_FILE="$LATEX_DIR/$LATEX_NAME"

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
  for dir_name in "${DIRNAMES[@]}"; do
    mkdir -p "$ROOT_DIR/$dir_name/logs"
  done

  # Run scripts
  for dir_name in "${DIRNAMES[@]}"; do
    if [ "$ALL" = true ]; then
      bash "$ROOT_DIR/bench.sh" -a $dir_name $NB_REPEAT
    else
      bash "$ROOT_DIR/bench.sh" $dir_name $NB_REPEAT
    fi
  done
}


# Remove logs
remove_logs() {
  for dir_name in "${DIRNAMES[@]}"; do
    rm -rf "$ROOT_DIR/$dir_name/logs/log_verbose_"*"_${NB_REPEAT}_"*.txt
    rm -rf "$ROOT_DIR/$dir_name/logs/log_"*"_${NB_REPEAT}_"*.txt
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

  for dir_name in "${DIRNAMES[@]}"; do

    SEARCH="log_verbose_*_${NB_REPEAT}_*.txt"
    find "$ROOT_DIR/$dir_name/logs" -type f -name "$SEARCH" | sort -t '_' -k 4 -rn | while read -r current_log; do
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
    find "$ROOT_DIR/$dir_name/logs" -type f -name "$SEARCH_SHORT" ! -name "$SEARCH" | sort -t '_' -k 4 -rn | while read -r current_log; do
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


# Remove latex
remove_latex() {
  for dir_name in "${DIRNAMES[@]}"; do
    rm -rf "$ROOT_DIR/$dir_name/latex/latex_"*"_${NB_REPEAT}_"*.txt
  done

  rm -rf "$LATEX_FILE"
}


# Make latex
make_latex() {
  # Make the latex dir
  mkdir -p "$LATEX_DIR"

  # Make the global latex
  echo "Algorithm name;Is opt algorithm;Ratio wasm-opt -O3 [Node] / wasm-opt -O4 [Node];Ratio wasm-as [Node] / best-wasm-opt [Node];Ratio wasm-as [Node] / X86-64;Ratio wasm-opt -O3 [Node] / X86-64;Ratio wasm-opt -O4 [Node] / X86-64;Ratio best-Wasm [Node] / X86-64;Ratio wasm-opt -O3 [Firefox] / wasm-opt -O4 [Firefox];Ratio wasm-as [Firefox] / best-wasm-opt [Firefox];Ratio wasm-as [Firefox] / X86-64;Ratio wasm-opt -O3 [Firefox] / X86-64;Ratio wasm-opt -O4 [Firefox] / X86-64;Ratio best-Wasm [Firefox] / X86-64;Ratio wasm-as [Node] / wasm-as [Firefox];Ratio wasm-opt -O3 [Node] / wasm-opt -O3 [Firefox];Ratio wasm-opt -O4 [Node] / wasm-opt -O4 [Firefox];Ratio best-Wasm [Node] / best-Wasm [Firefox];Ratio best-Wasm / X86-64" > "$LATEX_FILE"

  for dir_name in "${DIRNAMES[@]}"; do

    SEARCH="latex_*_${NB_REPEAT}_*.txt"
    find "$ROOT_DIR/$dir_name/latex" -type f -name "$SEARCH" | sort -t '_' -k 4 -rn | while read -r current_latex; do
      cat "$current_latex" >> "$LATEX_FILE"
    done

  done
}


# Main script
if [ "$RM_LOGS" = true ]; then
  remove_logs
elif [ "$MK_LOGS" = true ]; then
  make_logs
elif [ "$RM_LATEX" = true ]; then
  remove_latex
elif [ "$MK_LATEX" = true ]; then
  make_latex
else
  bench
  make_logs
  make_latex
fi

#!/bin/bash


# GLOBALS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

TEMPLATE_FILE="$SCRIPT_DIR/array_exports_template.txt"


# VERIFICATIONS

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error : template file '$TEMPLATE_FILE' don't exist."
  exit 1
fi


# GENERATION

while read -r type; do

  [ -z "$type" ] && continue # skip if empty line

  OUTPUT_FILE="$PROJECT_ROOT/array_exports_${type}.txt"
  sed -e "s/TYPE/$type/g" "$TEMPLATE_FILE" > "$OUTPUT_FILE"

done <<EOF
  i8
  i16
  i32
  i64
  v128
EOF

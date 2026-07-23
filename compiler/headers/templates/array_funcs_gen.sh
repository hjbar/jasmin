#!/bin/bash


# GLOBALS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

TEMPLATE_FILE1="$SCRIPT_DIR/array_funcs_template_pack.txt"
TEMPLATE_FILE2="$SCRIPT_DIR/array_funcs_template_unpack.txt"

# VERIFICATIONS

if [ ! -f "$TEMPLATE_FILE1" ]; then
  echo "Error : template file '$TEMPLATE_FILE1' don't exist."
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE2" ]; then
  echo "Error : template file '$TEMPLATE_FILE2' don't exist."
  exit 1
fi


# GENERATION

while read -r type1 type2; do
  [ -z "$type1" ] && continue # skip if empty line

  OUTPUT_FILE="$PROJECT_ROOT/array_funcs_${type1}.txt"
  sed -e "s/TYPE1/$type1/g" -e "s/TYPE2/$type2/g" "$TEMPLATE_FILE1" > "$OUTPUT_FILE"
done <<EOF
  i8  i32
  i16 i32
EOF

while read -r type1 type2; do
  [ -z "$type1" ] && continue # skip if empty line

  OUTPUT_FILE="$PROJECT_ROOT/array_funcs_${type1}.txt"
  sed -e "s/TYPE1/$type1/g" -e "s/TYPE2/$type2/g" "$TEMPLATE_FILE2" > "$OUTPUT_FILE"
done <<EOF
  i32 i32
  i64 i64
  v128 v128
EOF

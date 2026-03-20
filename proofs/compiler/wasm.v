From mathcomp Require Import ssreflect ssrfun ssrbool eqtype ssralg.
From Coq Require Import
  ZArith.
Require Import
  utils
  word.
Require Import arch_decl.
Require Import
  wasm_decl
  wasm_instr_decl.

Definition wasm_eval_cond (get: rflag -> result error bool) (c: condt) :
  result error bool :=
  match c with
  | dummy_condt => ok false
  end.

#[ export ]
Instance wasm : asm register register_ext xregister rflag condt wasm_op :=
  {
    eval_cond := fun _ => wasm_eval_cond;
  }.

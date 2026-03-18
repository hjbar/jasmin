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

(* [None] is used to model register x0. If later we model it properly, this
   should not be needed anymore. *)
Definition sem_cond_arg (get : register -> word wasm_reg_size) ro :=
  match ro with
  | None => wrepr _ 0
  | Some r => get r
  end.

Definition sem_cond_kind ck (x y : word wasm_reg_size) :=
  match ck with
  | dummy_condt => false
  end%Z.

Definition wasm_eval_cond (get: register -> word wasm_reg_size) (c: condt) :
  result error bool :=
  ok
    (sem_cond_kind c
      (sem_cond_arg get (Some dummy_register))
      (sem_cond_arg get (Some dummy_register))).

#[ export ]
Instance wasm : asm register register_ext xregister rflag condt wasm_op :=
  {
    eval_cond := fun r _ => wasm_eval_cond r;
  }.

From mathcomp Require Import ssreflect ssrfun ssrbool eqtype.
From mathcomp Require Import word_ssrZ.

Require Import
  compiler_util
  expr
  fexpr
  linear.
Require Import
  arch_decl.
Require Import
  wasm_decl
  wasm_instr_decl.

(* Returns true for imm comprised between -2048 (-2ˆ11) and 2047 (2ˆ11 - 1); else otherwise*)
Definition is_arith_small (imm : Z) : bool := (- Z.pow 2 11 <=? imm)%Z && (imm <? Z.pow 2 11)%Z.
Definition is_arith_small_neg (imm: Z) : bool := is_arith_small(-imm).

Module WASMFopn_core.
  #[local]
  Open Scope Z.

  Definition opn_args := (seq lexpr * wasm_op * seq rexpr)%type.

  Definition op_gen mn x res : opn_args :=
    ([:: LLvar x ], mn, res).
  Definition op_un_reg mn x y := op_gen mn x [:: rvar y ].
  Definition op_un_imm mn x imm := op_gen mn x [:: rconst reg_size imm ].
  Definition op_bin_reg mn x y z := op_gen mn x [:: rvar y; rvar z ].
  Definition op_bin_imm mn x y imm := op_gen mn x [:: rvar y; rconst reg_size imm ].
  Definition neg_op_bin_imm mn x y imm := op_gen mn x [:: rvar y; rconst reg_size (- imm) ].

End WASMFopn_core.

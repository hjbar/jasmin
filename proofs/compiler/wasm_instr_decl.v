(* WASM 32I instruction set *)

From elpi.apps Require Import derive.std.
From mathcomp Require Import ssreflect ssrfun ssrbool seq eqtype ssralg.
From mathcomp Require Import word_ssrZ.

Require Import
  sem_type
  shift_kind
  strings
  utils
  word.
Require xseq.
Require Import
  sopn
  arch_decl
  arch_utils.
Require Import wasm_decl.


Module E.
  Definition no_semantics : error := ErrType.
End E.

(* -------------------------------------------------------------------- *)
(* Printing. *)

Definition pp_name name args :=
  {|
    pp_aop_name := name;
    pp_aop_ext := PP_name;
    pp_aop_args := map (fun a => (reg_size, a)) args;
  |}.

(* -------------------------------------------------------------------- *)
(* WASM 32I Base Integer instructions (operators). *)

#[only(eqbOK)] derive
Variant wasm_op : Type := .

#[ export ]
Instance eqTC_wasm_op : eqTypeC wasm_op :=
  { ceqP := wasm_op_eqb_OK }.

Canonical wasm_op_eqType := @ceqT_eqType _ eqTC_wasm_op.


(* -------------------------------------------------------------------- *)
(* Common semantic types. *)

Notation ty_r := (sem_ltuple [:: lreg ]) (only parsing).
Notation ty_rr := (sem_ltuple [:: lreg; lreg ]) (only parsing).

(* -------------------------------------------------------------------- *)
(* Instruction semantics and description. *)


(* -------------------------------------------------------------------- *)
(* Description of instructions. *)

Definition wasm_instr_desc (mn : wasm_op) : instr_desc_t :=
  match mn with
  end.

Definition wasm_prim_string : seq (string * prim_constructor wasm_op) := [::].

#[ export ]
Instance wasm_op_decl : asm_op_decl wasm_op :=
  {|
    instr_desc_op := wasm_instr_desc;
    prim_string := wasm_prim_string;
  |}.

Definition wasm_prog := @asm_prog _ _ _ _ _ _ _ wasm_op_decl.

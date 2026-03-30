From elpi.apps Require Import derive.std.
From mathcomp Require Import ssreflect ssrfun ssrbool eqtype fintype ssralg.
From mathcomp Require Import word_ssrZ.

Require Import
  expr
  flag_combination
  sem_type
  shift_kind
  strings
  utils
  wsize.

Require Import
  arch_decl
  arch_utils.

(* --------------------------------------------- *)
Definition wasm_reg_size := U32.
Definition wasm_xreg_size := U64.

(* -------------------------------------------------------------------- *)
(* Registers. *)

#[only(eqbOK)] derive
Variant register : Type := RSP.

#[ export ]
Instance eqTC_register : eqTypeC register :=
  { ceqP := register_eqb_OK }.

Canonical wasm_register_eqType := @ceqT_eqType _ eqTC_register.

Definition registers :=
  [:: RSP].


Lemma register_fin_axiom : Finite.axiom registers.
Proof. by case. Qed.

#[ export ]
Instance finTC_register : finTypeC register :=
  {
    cenum  := registers;
    cenumP := register_fin_axiom;
  }.

Canonical register_finType := @cfinT_finType _ finTC_register.

Definition register_to_string (r : register) : string :=
  match r with
  | RSP => "RSP"
  end.

#[ export ]
Instance reg_toS : ToString (lword wasm_reg_size) register :=
  {| category  := "register"
   ; to_string := register_to_string
  |}.


(* -------------------------------------------------------------------- *)
(* Conditions. *)

#[only(eqbOK)] derive
Variant condt : Type := dummy_condt.

#[ export ]
Instance eqTC_condt : eqTypeC condt :=
  { ceqP := condt_eqb_OK }.

Canonical condt_eqType := @ceqT_eqType _ eqTC_condt.

(* -------------------------------------------------------------------- *)
(* Dummy Flag combinations. *)

(* TODO: should we fail/return None instead of this dummy? *)
Definition wasm_fc_of_cfc (cfc : combine_flags_core) : flag_combination :=
  FCVar0 .

#[global]
Instance wasm_fcp : FlagCombinationParams :=
  {
    fc_of_cfc := wasm_fc_of_cfc;
  }.

(* -------------------------------------------------------------------- *)
(* Architecture declaration. *)

Notation register_ext := empty.
Notation xregister := empty.
Notation rflag := empty.

Definition wasm_check_CAimm (checker : caimm_checker_s) ws (w : word ws) : bool :=
  match checker with
  | CAimmC_none => true
  | CAimmC_arm_shift_amout _ | CAimmC_arm_wencoding _ | CAimmC_arm_0_8_16_24
  | CAimmC_riscv_12bits_signed | CAimmC_riscv_5bits_unsigned =>
    false
  end.

#[ export ]
Instance wasm_decl : arch_decl register register_ext xregister rflag condt :=
  { reg_size  := wasm_reg_size
  ; xreg_size := wasm_xreg_size
  ; cond_eqC  := eqTC_condt
  ; toS_r     := reg_toS
  ; toS_rx    := empty_toS lword32
  ; toS_x     := empty_toS lword64
  ; toS_f     := empty_toS lbool
  ; reg_size_neq_xreg_size := refl_equal
  ; ad_rsp := RSP
  ; ad_fcp := wasm_fcp
  ; check_CAimm := wasm_check_CAimm
  }.

Definition wasm_linux_call_conv : calling_convention :=
{| callee_saved := map ARReg [::]
 ; callee_saved_not_bool := erefl true
 ; call_reg_args  := [::]
 ; call_xreg_args := [::]
 ; call_reg_ret   := [::]
 ; call_xreg_ret  := [::]
 ; call_reg_ret_uniq := erefl true;
|}.

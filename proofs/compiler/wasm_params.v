From mathcomp Require Import ssreflect ssrfun ssrbool ssrnat eqtype.
From mathcomp Require Import ssralg.
From mathcomp Require Import word_ssrZ.

Require Import
  arch_params
  compiler_util
  expr
  fexpr.
Require Import
  lea
  linearization
  lowering
  stack_alloc_params
  stack_zeroization
  slh_lowering.
Require Import
  arch_decl
  arch_extra
  asm_gen.

Require Import
  wasm_decl
  wasm_extra
  wasm_instr_decl
  wasm_params_core
  wasm_params_common.

Section Section.
Context {atoI : arch_toIdent}.

(* ------------------------------------------------------------------------ *)
(* Stack alloc parameters. *)

Print instr_r.
Print mov_kind.
Print pexpr.
Print sop2.
Print op_kind.
Print Uptr.
Print atype.
Print sop1.
Print sopn.
Print pseudo_operator.pseudo_operator.

Definition wasm_mov_ofs
  (x : lval) (tag : assgn_tag) (movk : mov_kind) (y : pexpr) (ofs : pexpr) :
  option instr_r := Some (Cassgn x tag (aword Uptr) (Papp2 (Oadd (Op_w Uptr)) y ofs)).

Definition wasm_immediate (x: var_i) (z : Z) :=
  Cassgn (Lvar x) AT_none (aword Uptr) (Papp1 (Oword_of_int Uptr) (Pconst z)).

Definition wasm_swap (t : assgn_tag) (x y z w : var_i) :=
  Copn [:: Lvar x; Lvar y] t (Opseudo_op (pseudo_operator.Oswap (aword Uptr))) [:: Plvar z; Plvar w].

Definition wasm_saparams : stack_alloc_params :=
  {|
    sap_mov_ofs := wasm_mov_ofs;
    sap_immediate := wasm_immediate;
    sap_swap := wasm_swap;
  |}.


(* ------------------------------------------------------------------------ *)
(* Speculative execution operator lowering parameters. *)

Definition wasm_shparams : sh_params :=
  {|
    shp_lower := fun _ _ _ => None;
  |}.


(* ------------------------------------------------------------------------ *)
(* Assembly generation parameters. *)

Definition assemble_cond ii (e : fexpr) : cexec condt :=
  Error (E.berror ii e "Can't assemble condition.").

Definition is_valid_address (addr : reg_address) :=
  match addr.(ad_disp) != 0%w, isSome addr.(ad_offset), addr.(ad_scale) != 0 with
  | false, false, false => true
  | true, false, false => true
  | _, _, _ => false
  end.

Definition wasm_agparams : asm_gen_params :=
  {|
    agp_assemble_cond := assemble_cond;
    agp_is_valid_address := is_valid_address;
  |}.


(* ------------------------------------------------------------------------ *)
(* Shared parameters. *)

Definition wasm_is_move_op (o : asm_op_t) : bool := false.

Definition wasm_params : architecture_params_wasm :=
  {|
    ap_sap_wasm := wasm_saparams;
    ap_plp_wasm := false;
    ap_shp_wasm := wasm_shparams;
    ap_agp_wasm := wasm_agparams;
    ap_is_move_op_wasm := wasm_is_move_op;
  |}.

End Section.

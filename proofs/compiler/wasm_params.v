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

(* TODO: kinda strange no ? *)
Definition wasm_mov_ofs
  (x : lval) (tag : assgn_tag) (movk : mov_kind) (y : pexpr) (ofs : pexpr) :
  option instr_r := None.

Definition wasm_immediate (x: var_i) (z : Z) :=
  Cassert ("dummy_assert"%string, Pbool false).

Definition wasm_swap (t : assgn_tag) (x y z w : var_i) :=
  Cassert ("dummy_assert"%string, Pbool false).

(*
Definition riscv_mov_ofs
  (x : lval) (tag : assgn_tag) (movk : mov_kind) (y : pexpr) (ofs : pexpr) :
  option instr_r :=
  let mk oa :=
    let: (op, args) := oa in
     Some (Copn [:: x ] tag (Oriscv op) args) in
  match movk with
  | MK_LEA => mk (LA, [:: if is_zero Uptr ofs then y else add y ofs ])
  | MK_MOV =>
    match x with
    | Lvar x_ =>
      if is_Pload y then
        if is_zero Uptr ofs then mk (LOAD Signed U32, [:: y ]) else None
      else
        match mk_lea Uptr (add y ofs) with
        | None => None
        | Some lea =>
          match lea.(lea_base), lea.(lea_offset) with
          | None, _ => None (* impossible *)
          | Some base, None =>
            if lea.(lea_disp) == 0%Z then mk (MV, [:: Plvar base ])
            else
              (* This allows to remove constraint in register allocation *)
              if is_arith_small lea.(lea_disp) then mk (ADDI, [:: Plvar base; cast_const lea.(lea_disp) ])
              else
                Some (Copn [:: x ] tag (Oasm (ExtOp Oriscv_add_large_imm)) [:: Plvar base; cast_const lea.(lea_disp) ])
          | Some base, Some off =>
            if (lea.(lea_disp) == 0%Z) && (lea.(lea_scale) == 1%Z) then
              mk (ADD, [:: Plvar base; Plvar off ])
            else None
          end
        end
    | Lmem _ _ _ _ =>
      if is_zero Uptr ofs then mk (STORE U32, [:: y ]) else None
    | _ => None
    end
  end.

Definition riscv_immediate (x: var_i) z :=
  Copn [:: Lvar x ] AT_none (Oriscv LI) [:: cast_const z ].

Definition riscv_swap t (x y z w : var_i) :=
  Copn [:: Lvar x; Lvar y] t (Oasm (ExtOp (SWAP reg_size))) [:: Plvar z; Plvar w].
*)

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

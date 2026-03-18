From elpi.apps Require Import derive.std.
From HB Require Import structures.
From mathcomp Require Import ssreflect ssrfun ssrbool eqtype ssralg.

Require Import
  compiler_util
  expr
  fexpr
  sopn
  utils.
Require Export
  arch_decl
  arch_extra
  wasm_params_core.
Require Import
  wasm_decl
  wasm_instr_decl
  wasm.

Local Notation E n := (sopn.ADExplicit n sopn.ACR_any).

#[only(eqbOK)] derive
Variant wasm_extra_op : Type := .

HB.instance Definition _ := hasDecEq.Build wasm_extra_op wasm_extra_op_eqb_OK.

#[ export ]
Instance eqTC_wasm_extra_op : eqTypeC wasm_extra_op :=
  { ceqP := wasm_extra_op_eqb_OK }.

Definition get_instr_desc (o: wasm_extra_op) : instruction_desc :=
  match o with
  end.

(* Without priority 1, this instance is selected when looking for an [asmOp],
 * meaning that extra ops are the only possible ops. With that priority,
 * [arch_extra.asm_opI] is selected first and we have both base and extra ops.
*)
#[ export ]
Instance wasm_extra_op_decl : asmOp wasm_extra_op | 1 :=
  {
    asm_op_instr := get_instr_desc;
    prim_string := [::];
  }.

Module E.

Definition pass_name := "asmgen"%string.

Definition internal_error (ii : instr_info) (msg : string) :=
  {|
    pel_msg := compiler_util.pp_s msg;
    pel_fn := None;
    pel_fi := None;
    pel_ii := Some ii;
    pel_vi := None;
    pel_pass := Some pass_name;
    pel_internal := true;
  |}.

Definition error (ii : instr_info) (msg : string) :=
  {|
    pel_msg := compiler_util.pp_s msg;
    pel_fn := None;
    pel_fi := None;
    pel_ii := Some ii;
    pel_vi := None;
    pel_pass := Some pass_name;
    pel_internal := false;
  |}.

End E.

Definition asm_args_of_opn_args
  : seq WASMFopn_core.opn_args -> seq (asm_op_msb_t * lexprs * rexprs) :=
  map (fun '(les, aop, res) => ((None, aop), les, res)).

Definition assemble_extra
           (ii: instr_info)
           (o: wasm_extra_op)
           (outx: lexprs)
           (inx: rexprs)
           : cexec (seq (asm_op_msb_t * lexprs * rexprs)) :=
  match o with
  end.

#[ export ]
Instance wasm_extra {atoI : arch_toIdent} :
  asm_extra register register_ext xregister rflag condt wasm_op wasm_extra_op :=
  { to_asm := assemble_extra }.

(* This concise name is convenient in OCaml code. *)
Definition wasm_extended_op {atoI : arch_toIdent} :=
  @extended_op _ _ _ _ _ _ _ wasm_extra.

Definition Owasm {atoI : arch_toIdent} o : @sopn wasm_extended_op _ := Oasm (BaseOp (None, o)).

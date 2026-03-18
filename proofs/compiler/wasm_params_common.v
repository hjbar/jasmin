From mathcomp Require Import ssreflect ssrfun ssrbool.
From mathcomp Require Import word_ssrZ.

Require Import
  arch_params
  compiler_util
  expr
  fexpr
  linear.
Require Import
  arch_decl
  arch_extra.
Require Import
  wasm_decl
  wasm_extra
  wasm_instr_decl
  wasm_params_core.

Module WASMFopn.

  #[local]
  Open Scope Z.

  Section WITH_PARAMS.

  Context {atoI : arch_toIdent}.

  Definition to_opn '(d, o, e) : fopn_args := (d, Oasm (BaseOp(None, o)), e).
  Definition to_opn_ext '(d, o, e) : fopn_args := (d, Oasm (ExtOp o), e).

  End WITH_PARAMS.

End WASMFopn.

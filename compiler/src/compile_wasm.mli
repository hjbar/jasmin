open Prog
open Wsize
open Sopn

val preprocess :
  wsize -> wsize -> 'asm asmOp -> (unit, 'asm) pprog -> (unit, 'asm) prog
(** Preprocessing before translation to Coq representation:
    - substitution of parameters;
    - inserts `#copy` operators where needed;
    - fixes the length information in `Ocopy` operations;
    - typechecks the result.

    Raises `Typing.TyError`. *)

val parse_file :
  ('reg, 'regx, 'xreg, 'rflag, 'cond, 'asm_op, 'extra_op) Pretyping.arch_info ->
  ?idirs:(string * string) list ->
  string ->
  ('reg, 'regx, 'xreg, 'rflag, 'cond, 'asm_op, 'extra_op) Arch_extra.extended_op
  Pretyping.Env.env
  * ( unit,
      ( 'reg,
        'regx,
        'xreg,
        'rflag,
        'cond,
        'asm_op,
        'extra_op )
      Arch_extra.extended_op )
    pmod_item
    list
  * Syntax.pprogram
(** Parsing and pre-typing of a complete file. Require directives are resolved
    using named path given through the [idirs] argument and the JASMINPATH
    environment variable.

    Raises `Pretyping.TyError` and `Syntax.ParseError`. *)

val do_spill_unspill :
  'asm asmOp ->
  ?debug:bool ->
  (unit, 'asm) prog ->
  ((unit, 'asm) prog, Utils.hierror) result
(** Removes (aka implements) #spill and #unspill instructions. *)

val do_wint_int :
  (module Arch_full.Arch
     with type reg = 'reg
      and type regx = 'regx
      and type xreg = 'xreg
      and type rflag = 'rflag
      and type cond = 'cond
      and type asm_op = 'asm_op
      and type extra_op = 'extra_op) ->
  (unit,
    ('reg, 'regx, 'xreg, 'rflag, 'cond, 'asm_op, 'extra_op) Arch_extra.extended_op Sopn.asm_op_t)
   prog ->
  (unit,
    ('reg, 'regx, 'xreg, 'rflag, 'cond, 'asm_op, 'extra_op) Arch_extra.extended_op Sopn.asm_op_t)
   prog

val compile :
(module Arch_full.Arch_wasm with type asm_op = 'asm_op and type cond = 'cond and type extra_op = 'extra_op and type reg = 'reg and type regx = 'regx and type rflag = 'rflag and type xreg = 'xreg) ->
(debug:bool ->
 Compiler_wasm.compiler_step ->
 (unit,
  ('reg, 'regx, 'xreg, 'rflag, 'cond, 'asm_op, 'extra_op)
  Arch_extra.extended_op)
 prog -> unit) ->
'a * ('b, 'c, 'd) gfunc list ->
(('reg, 'regx, 'xreg, 'rflag, 'cond, 'asm_op, 'extra_op)
 Arch_extra.extended_op, unit, unit)
Expr._prog ->
('reg, 'regx, 'xreg, 'rflag, 'cond, 'asm_op, 'extra_op)
Arch_extra.extended_op E.prog Compiler_util.cexec

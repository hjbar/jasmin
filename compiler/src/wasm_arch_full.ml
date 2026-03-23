open Arch_decl
open Wasm_decl

module type Wasm_input = sig
  val call_conv : (register, Arch_utils.empty, Arch_utils.empty, Arch_utils.empty, condt) calling_convention
end

module Wasm_core = struct
  type reg = register
  type regx = Arch_utils.empty
  type xreg = Arch_utils.empty
  type rflag =  Arch_utils.empty
  type cond = condt
  type asm_op = Arch_utils.empty (* type asm_op = Wasm_instr_decl.wasm_op *)
  type extra_op = Arch_utils.empty (* type extra_op = Wasm_extra.wasm_extra_op *)

  let atoI = X86_arch_full.atoI wasm_decl

  let asm_e =  Wasm_extra.wasm_extra atoI
  let aparams = Wasm_params.wasm_params atoI
  let known_implicits = []

  (* FIXME: use wasm_params_core instead of riscv *)
  let alloc_stack_need_extra sz =
    not (Riscv_params_core.is_arith_small (Conv.cz_of_z sz))

  (* FIXME RISCV: check if everything is ct *)
  let is_ct_asm_op (o : asm_op) =
    match o with
    | _ -> true

  let is_ct_asm_extra (_o : extra_op) = true

  let is_doit_asm_op (_o : asm_op) = true

  (* All of the extra ops compile into DIT instructions only, but this needs to be checked manually. *)
  let is_doit_asm_extra (_o : extra_op) = true

end

module Wasm (Lowering_params : Wasm_input) : Arch_full.Core_arch_wasm
  with type reg = register
   and type regx = Arch_utils.empty
   and type xreg = Arch_utils.empty
   and type rflag = Arch_utils.empty
   and type cond = condt
   and type asm_op = Arch_utils.empty (* and type asm_op = Wasm_instr_decl.wasm_op *)
   and type extra_op = Arch_utils.empty = struct (* and type extra_op = Wasm_extra.wasm_extra_op = struct *)
  include Wasm_core
  include Lowering_params

  let pp_asm = Pp_wasm.print_prog

  let callstyle = Arch_full.StackDirect
end

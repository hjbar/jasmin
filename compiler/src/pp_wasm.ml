open Arch_decl
open AsmTargetBuilder
(* open Utils *)
open PrintASM
open Asm_utils

(* Architecture imports*)
open Wasm_decl
(* open Wasm_instr_decl *)

let arch = wasm_decl
(* let imm_pre = "" *)

(* We support the following RISC-V memory accesses.
   Offset addressing:
     - A base register and an immediate offset (displacement):
       #+/-<imm>(<reg>) (where + can be omitted).
*)
(*
let pp_reg_address_aux base disp off scal =
  match (disp, off, scal) with
  | None, None, None ->
      Format.asprintf "(%s)" base
  | Some disp, None, None ->
      Format.asprintf "%s%s(%s)" imm_pre disp base
  | _, _, _ ->
      hierror
      ~loc:Lnone
      ~kind:"assembly printing"
      ~internal:true
      "the address computation is too complex: an intermediate variable might be needed"
*)

(* let pp_imm = pp_imm imm_pre *)

let pp_register = pp_register arch

(*
let pp_reg_address addr =
  let addr = parse_reg_address arch addr in
  pp_reg_address_aux addr.base addr.displacement addr.offset addr.scale
*)

let pp_ct (ct : Wasm_decl.condt) =
  match ct with
  | Coq_dummy_condt -> "dummy_condt"

(*
let pp_cond_arg (ro: Wasm_decl.register option) =
  match ro with
  | Some r -> pp_register r
  | None -> "x0"
*)

(*
let pp_asm_arg (arg : (register, Arch_utils.empty, Arch_utils.empty, Arch_utils.empty, condt) asm_arg) =
  match arg with
  | Condt _ -> None
  | Imm (ws, w) -> Some (pp_imm (Conv.z_of_word ws w))
  | Reg r -> Some (pp_register r)
  | Regx _ -> .
  | Addr (Areg ra) ->
    Some (pp_reg_address ra)
  | Addr  (Arip r) -> Some (pp_rip_address r)
  | XReg _ -> .
*)

(*
let pp_iname_ext _ = ""
let pp_iname2_ext ext _ _ = ext
*)

(*
let pp_ext = function
 | PP_error             -> assert false
 | PP_name              -> ""
 | PP_iname ws          -> pp_iname_ext ws
 | PP_iname2(s,ws1,ws2) -> pp_iname2_ext s ws1 ws2
 | PP_viname(_ve,_long)   -> assert false
 | PP_viname2(_ve1, _ve2) -> assert false
 | PP_ct _ct              -> assert false
*)

(*
let pp_name_ext pp_op =
  Format.asprintf "%s%s" pp_op.pp_aop_name (pp_ext pp_op.pp_aop_ext)
*)

module WasmTarget: AsmTarget
  with type reg = Wasm_decl.register
  and type regx = Arch_utils.empty
  and type xreg = Arch_utils.empty
  and type rflag = Arch_utils.empty
  and type cond = Wasm_decl.condt
  and type asm_op = Wasm_instr_decl.wasm_op
= struct

  type reg   = Wasm_decl.register
  type regx  = Arch_utils.empty
  type xreg  = Arch_utils.empty
  type rflag = Arch_utils.empty
  type cond  = Wasm_decl.condt
  type asm_op = Wasm_instr_decl.wasm_op


  (* TODO_RISCV: Review. *)
  let headers = []

  let data_segment_header =
    [
      Instr (".p2align", ["5"]) ;
      Label global_datas_label
    ]

  let function_directives = []

  let function_header = []

  let function_tail = []

  let pp_instr_r fn instr =
    match instr with
    | ALIGN ->
        failwith "TODO_WASM: pp_instr align"

    | LABEL (_, lbl) ->
        [ Label (string_of_label fn lbl) ]

    | STORELABEL (dst, lbl) ->
        [ Instr ("adr", [ pp_register dst; string_of_label fn lbl ]) ]

    | JMP lbl ->
        [ Instr ("j", [ pp_remote_label lbl ]) ]

    | JMPI arg ->
        begin match arg with
        (* | Reg RA -> [Instr ("ret", [])] *)
        | Reg r -> [ Instr ("jr", [ pp_register r ]) ]
        | _ -> failwith "TODO_WASM: pp_instr jmpi"
        end

    | Jcc (lbl, ct) ->
        let iname = pp_ct ct in
        [ Instr (iname, [ string_of_label fn lbl ]) ]

    | JAL _
    | CALL _
    | POPPC ->
        assert false

    | SysCall op ->
        [Instr ("call", [ Asm_utils.pp_syscall op ])]

    | AsmOp (_op, _args) -> assert false
      (*
        let id = instr_desc wasm_decl wasm_op_decl (None, op) in
        let pp = id.id_pp_asm args in
        let name = pp_name_ext pp in
        let args = List.filter_map (fun (_, a) -> pp_asm_arg a) pp.pp_aop_args in
        [ Instr (name, args) ]
      *)
end

module WasmPrinter = AsmTargetBuilder.Make(WasmTarget)

let print_prog fmt prog = PrintASM.pp_asm fmt (WasmPrinter.asm_of_prog prog)

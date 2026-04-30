open Format
open Wasm_ast

(* -------------------------------------------------------------------- *)

let rec group_by n =
  let rec split n l acc =
    match n, l with
    | 0, _
    | _, [] -> List.rev acc, l
    | n, x :: l -> split (n - 1) l (x :: acc)
  in
  function
  | [] -> []
  | l ->
    let group, l = split n l [] in
    group :: group_by n l

let is_visible = function Return [] -> false | _ -> true

let pp_sep_simple_space fmt () = fprintf fmt " "

let pp_sep_double_space fmt () = fprintf fmt "@ @ "

(* -------------------------------------------------------------------- *)

let pp_name (fmt : formatter) (name : name) : unit =
  fprintf fmt "%s" name

let pp_scope (fmt : formatter) (scope : scope) : unit =
  match scope with
  | Slocal -> fprintf fmt "local"
  | Sglob -> fprintf fmt "global"

let pp_sign (fmt : formatter) (sign : sign) : unit =
  match sign with
  | Signed -> fprintf fmt "s"
  | Unsigned -> fprintf fmt "u"

let pp_num_as_byte (fmt : formatter) (num : num) : unit =
  fprintf fmt "%s" (Z.format "%02x" num)

let pp_num (fmt : formatter) (num : num) : unit =
  Z.pp_print fmt num

let pp_nums (fmt : formatter) (nums : num list) : unit =
  pp_print_list ~pp_sep:pp_sep_simple_space pp_num fmt nums

let pp_var (fmt : formatter) (var : var) : unit =
  fprintf fmt "%a.%s" pp_name var.var_name (CoreIdent.string_of_uid var.var_uid)

(* -------------------------------------------------------------------- *)

let pp_size (fmt : formatter) (size : size) : unit =
  match size with
  | U8 -> fprintf fmt "8"
  | U16 -> fprintf fmt "16"
  | U32 -> fprintf fmt "32"
  | U64 -> fprintf fmt "64"

(* -------------------------------------------------------------------- *)

let pp_ty (fmt : formatter) (ty : ty) : unit =
  match ty with
  | I32 -> fprintf fmt "i32"
  | I64 -> fprintf fmt "i64"
  | V128 -> fprintf fmt "v128"
  | Simd I8x16 -> fprintf fmt "i8x16"
  | Simd I16x8 -> fprintf fmt "i16x8"
  | Simd I32x4 -> fprintf fmt "i32x4"
  | Simd I64x2 -> fprintf fmt "i64x2"

(* -------------------------------------------------------------------- *)

let pp_funname (fmt : formatter) (funname : funname) : unit =
  fprintf fmt "%s" funname.fn_name

(* -------------------------------------------------------------------- *)

let pp_param (fmt : formatter) (param : var) : unit =
  fprintf fmt "(param $%a %a)"
    pp_var param
    pp_ty param.var_ty

let pp_params (fmt : formatter) (params : var list) : unit =
  if params <> [] then
    fprintf fmt " @[<hov>%a@]"
      (pp_print_list ~pp_sep:pp_print_space pp_param) params

(* -------------------------------------------------------------------- *)

let pp_result (fmt : formatter) (result : ty list) : unit =
  if result <> [] then
    fprintf fmt " @[<hov>(result %a)@]"
      (pp_print_list ~pp_sep:pp_print_space pp_ty) result

(* -------------------------------------------------------------------- *)

let pp_local (fmt : formatter) (local : var) : unit =
  fprintf fmt "(local $%a %a)"
    pp_var local
    pp_ty local.var_ty

let pp_locals (fmt : formatter) (locals : var list) : unit =
  fprintf fmt "@[<v>%a@]"
    (pp_print_list ~pp_sep:pp_print_space pp_local) locals

(* -------------------------------------------------------------------- *)

let pp_unop (fmt : formatter) (unop : unop) : unit =
  match unop with
  | Extend sign -> fprintf fmt "i64.extend_i32_%a" pp_sign sign
  | Wrap -> fprintf fmt "i32.wrap_i64"
  | Not -> fprintf fmt "v128.not"
  | Splat simd -> fprintf fmt "%a.splat" pp_ty simd
  | Extract_lane ((Simd (I32x4 | I64x2) as simd), None, num) ->
    fprintf fmt "%a.extract_lane %a"
      pp_ty simd
      pp_num num
  | Extract_lane ((Simd (I8x16 | I16x8) as simd), Some sign, num) ->
    fprintf fmt "%a.extract_lane_%a %a"
      pp_ty simd
      pp_sign sign
      pp_num num
  | Extract_lane _ -> failwith "Instruction not well-formed"

let pp_binop (fmt : formatter) (binop : binop) : unit =
  match binop with
  | Add ty -> fprintf fmt "%a.add" pp_ty ty
  | Sub ty -> fprintf fmt "%a.sub" pp_ty ty
  | Mul ty -> fprintf fmt "%a.mul" pp_ty ty
  | Div (ty, sign) ->
    fprintf fmt "%a.div_%a"
      pp_ty ty
      pp_sign sign
  | Rem (ty, sign) ->
    fprintf fmt "%a.rem_%a"
      pp_ty ty
      pp_sign sign
  | And ty -> fprintf fmt "%a.and" pp_ty ty
  | Or ty -> fprintf fmt "%a.or" pp_ty ty
  | Xor ty -> fprintf fmt "%a.xor" pp_ty ty
  | Shr (ty, sign) ->
    fprintf fmt "%a.shr_%a"
      pp_ty ty
      pp_sign sign
  | Shl ty -> fprintf fmt "%a.shl" pp_ty ty
  | Rotr ty -> fprintf fmt "%a.rotr" pp_ty ty
  | Rotl ty -> fprintf fmt "%a.rotl" pp_ty ty
  | Eq ty -> fprintf fmt "%a.eq" pp_ty ty
  | Ne ty -> fprintf fmt "%a.ne" pp_ty ty
  | Lt (ty, sign) ->
    fprintf fmt "%a.lt_%a"
      pp_ty ty
      pp_sign sign
  | Le (ty, sign) ->
    fprintf fmt "%a.le_%a"
      pp_ty ty
      pp_sign sign
  | Gt (ty, sign) ->
    fprintf fmt "%a.gt_%a"
      pp_ty ty
      pp_sign sign
  | Ge (ty, sign) ->
    fprintf fmt "%a.ge_%a"
      pp_ty ty
      pp_sign sign
  | Swizzle -> fprintf fmt "i8x16.swizzle"
  | Shuffle nums -> fprintf fmt "i8x16.shuffle %a" pp_nums nums
  | Replace_lane (simd, num) ->
    fprintf fmt "%a.replace_lane %a"
      pp_ty simd
      pp_num num

let rec pp_instr (fmt : formatter) (instr : instr) : unit =
  match instr with
  | Nop -> fprintf fmt "(nop)"
  | Drop -> fprintf fmt "(drop)"
  | Unop (unop, instr) ->
    fprintf fmt "@[<hv 2>(%a@ %a)@]"
      pp_unop unop
      pp_instr instr
  | Binop (binop, instr1, instr2) ->
    fprintf fmt "@[<hv 2>(%a@ %a@ %a)@]"
      pp_binop binop
      pp_instr instr1
      pp_instr instr2
  | Const (ty, None, [ num ]) ->
    fprintf fmt "(%a.const %a)"
      pp_ty ty
      pp_num num
  | Const (ty, Some simd_ty, nums) ->
    fprintf fmt "(%a.const %a %a)"
      pp_ty ty
      pp_ty simd_ty
      pp_nums nums
  | Const _ -> failwith "Instruction not well-formed"
  | Get (scope, var) ->
    fprintf fmt "(%a.get $%a)"
      pp_scope scope
      pp_var var
  | Set (scope, var, Some instr) ->
    fprintf fmt "@[<hv 2>(%a.set $%a@ %a)@]"
      pp_scope scope
      pp_var var
      pp_instr instr
  | Set (scope, var, None) ->
    fprintf fmt "(%a.set $%a)"
      pp_scope scope
      pp_var var
  | Load (ty, None, None, instr) ->
    fprintf fmt "(%a.load %a)"
      pp_ty ty
      pp_instr instr
  | Load (ty, Some size, Some sign, instr) ->
    fprintf fmt "(%a.load%a_%a %a)"
      pp_ty ty
      pp_size size
      pp_sign sign
      pp_instr instr
  | Load _ -> failwith "Instruction not well-formed"
  | Store (ty, None, addr, Some instr) ->
    fprintf fmt "(%a.store %a %a)"
      pp_ty ty
      pp_instr addr
      pp_instr instr
  | Store (ty, None, addr, None) ->
    fprintf fmt "(%a.store %a)"
      pp_ty ty
      pp_instr addr
  | Store (ty, Some size, addr, Some instr) ->
    fprintf fmt "(%a.store%a %a %a)"
      pp_ty ty
      pp_size size
      pp_instr addr
      pp_instr instr
  | Store _ -> failwith "Instruction not well-formed"
  | If ([], cond, then_, else_) ->
    fprintf fmt "@[<v 2>(if@ %a@ @[<v 2>(then@ %a)@]@ @[<v 2>(else@ %a)@])@]"
      pp_instr cond
      pp_instrs then_
      pp_instrs else_
  | If (tys, cond, then_, else_) ->
    fprintf fmt "@[<v 2>(if@ (result %a)@ %a@ @[<v 2>(then@ %a)@]@ @[<v 2>(else@ %a)@])@]"
      (pp_print_list ~pp_sep:pp_print_space pp_ty) tys
      pp_instr cond
      pp_instrs then_
      pp_instrs else_
  | Call (funname, []) -> fprintf fmt "(call $%a)" pp_funname funname
  | Call (funname, instrs) -> fprintf fmt "@[<hov 2>(call $%a@ %a)@]" pp_funname funname pp_instrs instrs
  | Block (None, instrs) -> fprintf fmt "@[<v 2>(block @ %a)@]" pp_instrs instrs
  | Block (Some name, instrs) ->
    fprintf fmt "@[<v 2>(block $%a@ %a)@]"
      pp_name name
      pp_instrs instrs
  | Loop (None, instrs) -> fprintf fmt "@[<v 2>(loop @ %a)@]" pp_instrs instrs
  | Loop (Some name, instrs) ->
    fprintf fmt "@[<v 2>(loop $%a@ %a)@]"
      pp_name name
      pp_instrs instrs
  | Br name -> fprintf fmt "(br $%a)" pp_name name
  | Return [] -> assert false
  | Return instrs -> fprintf fmt "@[<hov 2>(return@ %a)@]" pp_instrs instrs

and pp_instrs (fmt : formatter) (instrs : instrs) : unit =
  instrs
  |> List.filter is_visible
  |> pp_print_list ~pp_sep:pp_print_space pp_instr fmt

(* -------------------------------------------------------------------- *)

let pp_func (fmt : formatter) (func : func) : unit =
  fprintf fmt "@[<v 2>(func $%a%a%a"
    pp_funname func.func_name
    pp_params func.func_params
    pp_result func.func_result;

  let instrs = List.filter is_visible func.func_instrs in

  if func.func_locals <> [] then
    fprintf fmt "@ %a" pp_locals func.func_locals;

  if func.func_locals <> [] && instrs <> [] then
    fprintf fmt "@\n";

  if instrs <> [] then
    fprintf fmt "@ %a" pp_instrs instrs;

  fprintf fmt "@]@\n)"

let pp_funcs (fmt : formatter) (funcs : func list) : unit =
  pp_print_list ~pp_sep:pp_sep_double_space pp_func fmt funcs

(* -------------------------------------------------------------------- *)

let pp_mem (fmt : formatter) (mem : mem) : unit =
  match mem.mem_max with
  | None ->
    fprintf fmt {|(import "%a" "%a" (memory %a))|}
      pp_name mem.mem_env
      pp_name mem.mem_name
      pp_num mem.mem_min
  | Some max ->
    fprintf fmt {|(import "%a" "%a" (memory %a %a))|}
      pp_name mem.mem_env
      pp_name mem.mem_name
      pp_num mem.mem_min
      pp_num max

let pp_mems (fmt : formatter) (mems : mem list) : unit =
  pp_print_list ~pp_sep:pp_sep_double_space pp_mem fmt mems

(* -------------------------------------------------------------------- *)

let pp_arg (fmt : formatter) (arg : ty) : unit =
  fprintf fmt "(param %a)" pp_ty arg

let pp_args (fmt : formatter) (args : ty list) : unit =
  if args <> [] then
    fprintf fmt " @[<hov>%a@]"
      (pp_print_list ~pp_sep:pp_print_space pp_arg) args

(* -------------------------------------------------------------------- *)

let pp_import (fmt : formatter) (import : import) : unit =
  fprintf fmt {|@[<hov 2>(import "%a" "%a"@ @[<hov 1>(func $%a|}
    pp_name import.import_env
    pp_funname import.import_name
    pp_funname import.import_name;

  if import.import_args <> [] then
    fprintf fmt "@ %a" pp_args import.import_args;

  if import.import_result <> [] then
    fprintf fmt "@ %a" pp_result import.import_result;

  fprintf fmt ")@])@]"

let pp_imports (fmt : formatter) (imports : import list) : unit =
  pp_print_list ~pp_sep:pp_sep_double_space pp_import fmt imports

(* -------------------------------------------------------------------- *)

let pp_byte (fmt : formatter) (byte : num) : unit =
  fprintf fmt "\\%a" pp_num_as_byte byte

let pp_bytes (fmt : formatter) (bytes : num list) : unit =
  List.iter (pp_byte fmt) bytes

(* -------------------------------------------------------------------- *)

let pp_data (fmt : formatter) ({ data_ofs; data_bytes } : data) : unit =
  match data_bytes with
  | [] -> ()
  | bytes ->
    let chunks = group_by 16 bytes in
    fprintf fmt "@[<v 2>(data (i32.const %a)" pp_num data_ofs;
    List.iter (fun chunk -> fprintf fmt {|@ "%a"|} pp_bytes chunk) chunks;
    fprintf fmt "@]@\n)"

let pp_datas (fmt : formatter) (datas : data list) : unit =
  pp_print_list ~pp_sep:pp_sep_double_space pp_data fmt datas

(* -------------------------------------------------------------------- *)

let pp_init (fmt : formatter) (func : func option) : unit =
  match func with
  | None -> ()
  | Some func -> pp_func fmt func

(* -------------------------------------------------------------------- *)

let pp_export (fmt : formatter) (funname : funname) : unit =
  fprintf fmt {|(export "%a" (func $%a))|}
    pp_funname funname
    pp_funname funname

let pp_exports (fmt : formatter) (exports : funname list) : unit =
  fprintf fmt "@[<v>%a@]"
    (pp_print_list ~pp_sep:pp_print_space pp_export) exports

(* -------------------------------------------------------------------- *)

let pp_start (fmt : formatter) (funname : funname option) : unit =
  match funname with
  | None -> ()
  | Some funname -> fprintf fmt "(start $%a)" pp_funname funname

(* -------------------------------------------------------------------- *)

let pp_module (fmt : formatter) (wasm_mod : wasm_module) : unit =
  let { mod_name; mod_mems; mod_imports; mod_datas; mod_funcs; mod_init; mod_exports; mod_start } = wasm_mod in

  fprintf fmt "@[<v 2>(module $%a" pp_name mod_name;

  if mod_mems <> [] then
    fprintf fmt "@\n@ %a" pp_mems mod_mems;

  if mod_imports <> [] then
    fprintf fmt "@\n@ %a" pp_imports mod_imports;

  if mod_datas <> [] then
    fprintf fmt "@\n@ %a" pp_datas mod_datas;

  if mod_funcs <> [] then
    fprintf fmt "@\n@ %a" pp_funcs mod_funcs;

  if mod_init <> None then
    fprintf fmt "@\n@ %a" pp_init mod_init;

  if mod_exports <> [] then
    fprintf fmt "@\n@ %a" pp_exports mod_exports;

  if mod_start <> None then
    fprintf fmt "@\n@ %a" pp_start mod_start;

  fprintf fmt "@]@\n@\n)"

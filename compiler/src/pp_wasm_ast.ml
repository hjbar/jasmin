open Format
open Wasm_ast
open Wasm_headers

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

let pp_raw (fmt : formatter) (str : string) : unit =
  let str = String.trim str in
  if str <> "" then
    let lines = String.split_on_char '\n' str in
    pp_print_list ~pp_sep:(fun fmt () -> fprintf fmt "@\n") pp_print_string fmt lines

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
  | I32  -> fprintf fmt "i32"
  | I64  -> fprintf fmt "i64"
  | V128 -> fprintf fmt "v128"
  | Simd I8x16 -> fprintf fmt "i8x16"
  | Simd I16x8 -> fprintf fmt "i16x8"
  | Simd I32x4 -> fprintf fmt "i32x4"
  | Simd I64x2 -> fprintf fmt "i64x2"
  | Extra I8  -> fprintf fmt "i8"
  | Extra I16 -> fprintf fmt "i16"
  | Ref name -> fprintf fmt "(ref $%a)" pp_name name

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
  | Max (simd, sign) ->
    fprintf fmt "%a.max_%a"
      pp_ty simd
      pp_sign sign
  | Min (simd, sign) ->
    fprintf fmt "%a.min_%a"
      pp_ty simd
      pp_sign sign

let pp_trinop (fmt : formatter) (trinop : trinop) : unit =
  match trinop with
  | Bitselect -> fprintf fmt "v128.bitselect"

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
  | Trinop (trinop, instr1, instr2, instr3) ->
    fprintf fmt "@[<hv 2>(%a@ %a@ %a@ %a)@]"
      pp_trinop trinop
      pp_instr instr1
      pp_instr instr2
      pp_instr instr3
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
  | Get (access, scope, var) -> pp_get fmt access scope var
  | Set (access, scope, var, instr_opt) -> pp_set fmt access scope var instr_opt
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

and pp_get (fmt : formatter) (access : access) (scope : scope) (var : var) : unit =
  match access with
  | VarAccess ->
    fprintf fmt "(%a.get $%a)"
      pp_scope scope
      pp_var var
  | ArrayAccess (ref_ty, None, instr) ->
    fprintf fmt "(array.get $%a (%a.get $%a) %a)"
      pp_name ref_ty
      pp_scope scope
      pp_var var
      pp_instr instr
  | ArrayAccess (ref_ty, Some sign, instr) ->
    fprintf fmt "(array.get_%a $%a (%a.get $%a) %a)"
      pp_sign sign
      pp_name ref_ty
      pp_scope scope
      pp_var var
      pp_instr instr
  | StructAccess (ref_ty, None, field_name) ->
    fprintf fmt "(struct.get $%a $%a (%a.get $%a))"
      pp_name ref_ty
      pp_name field_name
      pp_scope scope
      pp_var var
  | StructAccess (ref_ty, Some sign, field_name) ->
    fprintf fmt "(struct.get_%a $%a $%a (%a.get $%a))"
      pp_sign sign
      pp_name ref_ty
      pp_name field_name
      pp_scope scope
      pp_var var


and pp_set (fmt : formatter) (access : access) (scope : scope) (var : var) (instr_opt : instr option) : unit =
  match access, instr_opt with
  | VarAccess, None ->
    fprintf fmt "(%a.set $%a)"
      pp_scope scope
      pp_var var
  | VarAccess, Some instr ->
    fprintf fmt "@[<hv 2>(%a.set $%a@ %a)@]"
      pp_scope scope
      pp_var var
      pp_instr instr
  | ArrayAccess (ref_ty, None, idx), None ->
    fprintf fmt "(array.set $%a (%a.get $%a) %a)"
      pp_name ref_ty
      pp_scope scope
      pp_var var
      pp_instr idx
  | ArrayAccess (ref_ty, None, idx), Some instr ->
    fprintf fmt "@[<hv 2>(array.set $%a (%a.get $%a) %a@ %a)@]"
      pp_name ref_ty
      pp_scope scope
      pp_var var
      pp_instr idx
      pp_instr instr
  | StructAccess (ref_ty, None, field_name), None ->
    fprintf fmt "(struct.set $%a $%a (%a.get %a))"
      pp_name ref_ty
      pp_name field_name
      pp_scope scope
      pp_var var
  | StructAccess (ref_ty, None, field_name), Some instr ->
    fprintf fmt "@[<hv 2>(struct.set $%a $%a (%a.get %a)@ %a)@]"
      pp_name ref_ty
      pp_name field_name
      pp_scope scope
      pp_var var
      pp_instr instr
  | _ -> failwith "Instruction not well-formed"

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

let pp_mem_args (fmt : formatter) ((min, max) : (num * num option)) : unit =
  match max with
  | None -> fprintf fmt "%a" pp_num min
  | Some max ->
    fprintf fmt "%a %a"
      pp_num min
      pp_num max

let pp_mem (fmt : formatter) ({ mem_link; mem_env; mem_name; mem_min; mem_max } : mem) : unit =
  match mem_link, mem_env with
  | Import, Some mem_env ->
      fprintf fmt {|(import "%a" "%a" (memory $%a %a))|}
      pp_name mem_env
      pp_name mem_name
      pp_name mem_name
      pp_mem_args (mem_min, mem_max)
  | Export, None ->
      fprintf fmt {|(memory $%a (export "%a") %a)|}
      pp_name mem_name
      pp_name mem_name
      pp_mem_args (mem_min, mem_max)
  | _ -> failwith "Instruction not well-formed"

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

let pp_field (fmt : formatter) ((name, mut, ty) : field) : unit =
  match mut with
  | Mutable -> fprintf fmt "(field $%a (mut %a))" pp_name name pp_ty ty
  | Immutable -> fprintf fmt "(field $%a %a)" pp_name name pp_ty ty

let pp_kind (fmt : formatter) : ref_kind -> unit = function
  | Array (Mutable, ty) -> fprintf fmt "(array (mut %a))" pp_ty ty
  | Array (Immutable, ty) -> fprintf fmt "(array %a)" pp_ty ty
  | Struct fields -> pp_print_list ~pp_sep:pp_sep_simple_space pp_field fmt fields

let pp_decl (fmt : formatter) ({ decl_name; decl_kind } : decl) : unit =
  fprintf fmt "(type $%a %a)"
    pp_name decl_name
    pp_kind decl_kind

let pp_decls (fmt : formatter) (decls : decl list) : unit =
  fprintf fmt "@[<v>%a@]"
    (pp_print_list ~pp_sep:pp_print_space pp_decl) decls

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

let pp_module (fmt : formatter) (headers : wasm_headers) (wasm_mod : wasm_module) : unit =
  let { mod_name; mod_mems; mod_imports; mod_datas; mod_decls; mod_funcs; mod_init; mod_exports; mod_start } = wasm_mod in
  let { mem_header; import_header; data_header; decl_header; func_header; init_header; export_header; start_header } = headers in

  fprintf fmt "@[<v 2>(module $%a" pp_name mod_name;


  if mod_mems <> [] then
    fprintf fmt "@\n@ %a" pp_mems mod_mems;

  if mem_header <> "" then
    fprintf fmt "@ %a" pp_raw mem_header;


  if mod_imports <> [] then
    fprintf fmt "@\n@ %a" pp_imports mod_imports;

  if import_header <> "" then
    fprintf fmt "@ %a" pp_raw import_header;


  if mod_datas <> [] then
    fprintf fmt "@\n@ %a" pp_datas mod_datas;

  if data_header <> "" then
    fprintf fmt "@ %a" pp_raw data_header;


  if mod_decls <> [] then
    fprintf fmt "@\n@ %a" pp_decls mod_decls;

  if decl_header <> "" then
    fprintf fmt "@ %a" pp_raw decl_header;


  if mod_funcs <> [] then
    fprintf fmt "@\n@ %a" pp_funcs mod_funcs;

  if func_header <> "" then
    fprintf fmt "@\n@ %a" pp_raw func_header;


  if mod_init <> None then
    fprintf fmt "@\n@ %a" pp_init mod_init;

  if init_header <> "" then
    fprintf fmt "@\n@ %a" pp_raw init_header;


  if mod_exports <> [] then
    fprintf fmt "@\n@ %a" pp_exports mod_exports;

  if export_header <> "" then
    fprintf fmt "@ %a" pp_raw export_header;


  if mod_start <> None then
    fprintf fmt "@\n@ %a" pp_start mod_start;

  if start_header <> "" then
    fprintf fmt "@ %a" pp_raw start_header;


  fprintf fmt "@]@\n@\n)"

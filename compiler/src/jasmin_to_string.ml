open Utils
open Prog
open Glob_options

(* -------------------------------------------------------------------- *)

let ( +@ ) = Z.add

(* -------------------------------------------------------------------- *)

let cz2z = Conv.z_of_cz

let gvar_uid (gvar : 'len gvar) : uid =
  gvar.v_id

let gvar_name (gvar : 'len gvar) : string =
  Format.sprintf "%s.%s" (gvar.v_name) (string_of_uid (gvar_uid gvar))

let gvar_type (gvar : 'len gvar) : 'len gty =
  gvar.v_ty

let gvar_is_glob (gvar : 'len gvar) : bool =
  gvar.v_kind = Global

let igvar_name (gvar_i : 'len gvar_i) : string =
  gvar_name gvar_i.pl_desc

let ggvar_name (ggvar : 'len ggvar) : string =
  igvar_name ggvar.gv

(* -------------------------------------------------------------------- *)

let size2doc : Wsize.wsize -> string = function
  | U8   -> "U8"
  | U16  -> "U16"
  | U32  -> "U32"
  | U64  -> "U64"
  | U128 -> "U128"
  | U256 -> "U256"

let type2doc : 'len gty -> string = function
  | Bty Bool -> "bool"
  | Bty Int -> "int"
  | Bty (U wsize) -> Format.sprintf "word(%s)" (size2doc wsize)
  | Arr (wsize, len) -> Format.sprintf "arr(%s, %s)" (size2doc wsize) (string_of_int len)

let op_kind2doc : Operators.op_kind -> string = function
  | Op_int -> "op_int"
  | Op_w wsize -> Format.sprintf "op_w(%s)" (size2doc wsize)

let sign2doc : Wsize.signedness -> string = function
  | Signed -> "signed"
  | Unsigned -> "unsigned"

let cmp_kind2doc : Operators.cmp_kind -> string = function
  | Cmp_int -> "cmp_int"
  | Cmp_w (sign, wsize) -> Format.sprintf "cmp_w(%s, %s)" (sign2doc sign) (size2doc wsize)

(* -------------------------------------------------------------------- *)

let raise_error ?(loc : error_loc = Lnone) ?(kind = "compilation error") ?(sub_kind = "Stack Allocation to Wasm") ?(internal = false) ~funname msg =
  hierror ~loc ~funname ~kind ~sub_kind ~internal msg

let raise_dummy_error ?(kind = "compilation error") ?(sub_kind = "Stack Allocation to Wasm") ?(internal = false) msg =
  hierror ~loc:Lnone ~kind ~sub_kind ~internal msg

let raise_error_opt ?funname ?loc =
  if Option.is_some funname && Option.is_some loc then
    let funname = Option.get funname in
    let loc = Option.get loc in
    raise_error ~loc ~funname
  else
    raise_dummy_error

let size2error ?funname ?loc (wsize : Wsize.wsize) =
  raise_error_opt ?funname ?loc "Don't know how to handle this size %s" (size2doc wsize)

let type2error ?funname ?loc (gtype : 'len gty) =
  raise_error_opt ?funname ?loc "Don't know how to handle this type %s" (type2doc gtype)

let op_kind2error ?funname ?loc (op_kind : Operators.op_kind) =
  raise_error_opt ?funname ?loc "Don't know how to handle this kind of op %s" (op_kind2doc op_kind)

let cmp_kind2error ?funname ?loc (cmp_kind : Operators.cmp_kind) =
  raise_error_opt ?funname ?loc "Don't know how to handle this kind of cmp %s" (cmp_kind2doc cmp_kind)

let opext2error ?funname ?loc (wsize : Wsize.wsize) =
  raise_error_opt ?funname ?loc "Don't know how to handle this size for ext unary operators : %s" (size2doc wsize)

let expr2error ~(funname : string) ~(loc : error_loc) (expr : 'len gexpr) =
  let module Core = CoreArchFactory.Core_arch_WASM in
  let module Arch = Arch_full.Arch_from_Core_arch_wasm (Core) in

  let debug = !debug in
  raise_error ~loc ~funname "Don't know how to handle the expression %a" (Printer.pp_expr ~debug) expr

let instr2error ~(funname : string) ~(loc : error_loc) (instr : ('len, 'info, 'asm) ginstr) =
  let module Core = CoreArchFactory.Core_arch_WASM in
  let module Arch = Arch_full.Arch_from_Core_arch_wasm (Core) in

  let debug = !debug in
  raise_error ~loc ~funname "Don't know how to handle the instruction %a" (Printer.pp_instr ~debug U32 U32 Arch.asmOp) instr

(* -------------------------------------------------------------------- *)

let z2string : Z.t -> string = Z.to_string

let cz2string (cz : BinNums.coq_Z) : string = cz |> Conv.z_of_cz |> z2string

let size2string ?funname ?loc : Wsize.wsize -> string = function
  | U32 -> "i32"
  | U64 -> "i64"
  | _ as wsize -> size2error ?funname ?loc wsize

let type2string ?funname ?loc : 'len gty -> string = function
  | Bty (U wsize) -> size2string ?funname ?loc wsize
  | Bty Bool
  | Bty Int
  | Arr _ as gtype -> type2error ?funname ?loc gtype

let op_kind2string ?funname ?loc : Operators.op_kind -> string = function
  | Op_w wsize -> size2string ?funname ?loc wsize
  | Op_int as op_kind -> op_kind2error ?funname ?loc op_kind

let sign2string : Wsize.signedness -> string = function
  | Signed -> "s"
  | Unsigned -> "u"

let cmp_kind2string ?funname ?loc : Operators.cmp_kind -> string * string = function
  | Cmp_w (signedness, wsize) -> (op_kind2string ?funname ?loc (Op_w wsize), sign2string signedness)
  | Cmp_int as cmp_kind -> cmp_kind2error ?funname ?loc cmp_kind

let opext2string ?funname ?loc (ws1 : Wsize.wsize) (ws2 : Wsize.wsize) (sign : Wsize.signedness) : string =
  let ws2 =
    match ws1, ws2 with
    | (U32 | U64), U8  -> 8
    | (U32 | U64), U16 -> 16
    |        U64 , U32 -> 32
    | _ -> opext2error ?funname ?loc ws2
  in
  Format.sprintf "%s.load%d_%s" (size2string ?funname ?loc ws1) ws2 (sign2string sign)

let gvar_kind2string (gvar : 'len gvar) : string =
  if gvar_is_glob gvar then "global" else "local"

let igvar_kind2string (gvar_i : 'len gvar_i) : string =
  gvar_kind2string gvar_i.pl_desc

let ggvar_kind2string (ggvar : 'len ggvar) : string =
  igvar_kind2string ggvar.gv

let velem2string : Wsize.velem -> string = function
  | VE8  -> "i8x16"
  | VE16 -> "i16x8"
  | VE32 -> "i32x4"
  | VE64 -> "i64x2"

(* -------------------------------------------------------------------- *)

let rec expr2string ~(funname : string) ~(loc : error_loc) (expr : 'len gexpr) : string =
  let expr2string = expr2string ~funname ~loc in
  let unop2string = unop2string ~funname ~loc in
  let binop2string = binop2string ~funname ~loc ~expr in
  let expr2error = expr2error ~funname ~loc in
  let size2string = size2string ~funname ~loc in
  let type2string = type2string ~funname ~loc in

  match expr with
  | Pconst z -> z2string z
  | Pvar ggvar -> Format.sprintf "(%s.get $%s)" (ggvar_kind2string ggvar) (ggvar_name ggvar)
  | Pload (_aligned, wsize, expr) -> Format.sprintf "(%s.load %s)" (size2string wsize) (expr2string expr)
  | Papp1 (op, expr) -> unop2string op expr
  | Papp2 (op, e1, e2) -> Format.sprintf "(%s %s %s)" (binop2string op) (expr2string e1) (expr2string e2)
  | Pif (gtype, cond, then_expr, else_expr) ->
    Format.sprintf
      "(if (result %s) %s (then %s) (else %s))"
      (type2string gtype) (expr2string cond) (expr2string then_expr) (expr2string else_expr)
  | Pbool _
  | Parr_init _
  | Pget _
  | Psub _
  | PappN _ -> expr2error expr

and unop2string ~(funname : string) ~(loc : error_loc) (op : Operators.sop1) (expr : 'len gexpr) : string =
  let expr2string = expr2string ~funname ~loc in
  let expr2error = expr2error ~funname ~loc in
  let size2string = size2string ~funname ~loc in
  let op_kind2string = op_kind2string ~funname ~loc in
  let opext2string = opext2string ~funname ~loc in

  (* FIXME : Verify Owi1 operators *)
  match op with
  | Olnot wsize ->
    let size = size2string wsize in
    Format.sprintf "(%s.xor %s (%s.const -1))" size (expr2string expr) size
  | Oneg  op    ->
    let kind = op_kind2string op in
    Format.sprintf "(%s.sub (%s.const 0) %s)" kind kind (expr2string expr)
  | Owi1 (_sign, WIneg wsize) ->
    let size = size2string wsize in
    Format.sprintf "(%s.sub (%s.const 0) %s)" size size (expr2string expr)
  | _ ->
    let op =
      match op with
      | Oword_of_int wsize -> Format.sprintf "%s.const" (size2string wsize)
      | Osignext (ws1, ws2) -> opext2string ws1 ws2 Signed
      | Ozeroext (ws1, ws2) -> opext2string ws1 ws2 Unsigned
      | Owi1 (sign, WIwint_ext (U32, U64)) -> Format.sprintf "%s.extend_%s_%s" (size2string U64) (size2string U32) (sign2string sign)
      | Olnot _
      | Oneg _
      | Owi1 (_, WIneg _) -> assert false
      | Oint_of_word _
      | Onot
      | Owi1 _ -> expr2error expr
    in
    Format.sprintf "(%s %s)" op (expr2string expr)

and binop2string ~(funname : string) ~(loc : error_loc) ~(expr : 'len gexpr) (op : Operators.sop2) : string =
  let expr2error = expr2error ~funname ~loc in
  let size2string = size2string ~funname ~loc in
  let op_kind2string = op_kind2string ~funname ~loc in
  let cmp_kind2string = cmp_kind2string ~funname ~loc in

  match op with
  (* FIXME : Verify Owi2 operators *)
  | Oadd op -> Format.sprintf "%s.add" (op_kind2string op)
  | Omul op -> Format.sprintf "%s.mul" (op_kind2string op)
  | Osub op -> Format.sprintf "%s.sub" (op_kind2string op)
  | Odiv (sign, op) -> Format.sprintf "%s.div_%s" (op_kind2string op) (sign2string sign)
  | Omod (sign, op) -> Format.sprintf "%s.rem_%s" (op_kind2string op) (sign2string sign)
  | Oland wsize -> Format.sprintf "%s.and" (size2string wsize)
  | Olor wsize -> Format.sprintf "%s.or" (size2string wsize)
  | Olxor wsize -> Format.sprintf "%s.xor" (size2string wsize)
  | Olsr wsize -> Format.sprintf "%s.shr_u" (size2string wsize)
  | Olsl op -> Format.sprintf "%s.shl" (op_kind2string op)
  | Oasr op -> Format.sprintf "%s.shr_s" (op_kind2string op)
  | Oror wsize -> Format.sprintf "%s.rotr" (size2string wsize)
  | Orol wsize -> Format.sprintf "%s.rotl" (size2string wsize)
  | Oeq op -> Format.sprintf "%s.eq" (op_kind2string op)
  | Oneq op -> Format.sprintf "%s.ne" (op_kind2string op)
  | Olt cmp_kind ->
    let (typ, sign) = cmp_kind2string cmp_kind in
    Format.sprintf "%s.lt_%s" typ sign
  | Ole cmp_kind ->
    let (typ, sign) = cmp_kind2string cmp_kind in
    Format.sprintf "%s.le_%s" typ sign
  | Ogt cmp_kind ->
    let (typ, sign) = cmp_kind2string cmp_kind in
    Format.sprintf "%s.gt_%s" typ sign
  | Oge cmp_kind ->
    let (typ, sign) = cmp_kind2string cmp_kind in
    Format.sprintf "%s.ge_%s" typ sign
  | Ovadd (velem, U128) -> Format.sprintf "%s.add" (velem2string velem)
  | Ovsub (velem, U128) -> Format.sprintf "%s.sub" (velem2string velem)
  | Ovmul (velem, U128) -> Format.sprintf "%s.mul" (velem2string velem)
  | Ovlsr (velem, U128) -> Format.sprintf "%s.shr_u" (velem2string velem)
  | Ovlsl (velem, U128) -> Format.sprintf "%s.shl" (velem2string velem)
  | Ovasr (velem, U128) -> Format.sprintf "%s.shr_s" (velem2string velem)
  | Owi2 (_sign, wsize, WIadd) -> Format.sprintf "%s.add" (size2string wsize)
  | Owi2 (_sign, wsize, WImul) -> Format.sprintf "%s.mul" (size2string wsize)
  | Owi2 (_sign, wsize, WIsub) -> Format.sprintf "%s.sub" (size2string wsize)
  | Owi2 ( sign, wsize, WIdiv) -> Format.sprintf "%s.div_%s" (size2string wsize) (sign2string sign)
  | Owi2 ( sign, wsize, WImod) -> Format.sprintf "%s.rem_%s" (size2string wsize) (sign2string sign)
  | Owi2 (_sign, wsize, WIshl) -> Format.sprintf "%s.shl" (size2string wsize)
  | Owi2 ( sign, wsize, WIshr) -> Format.sprintf "%s.shr_%s" (size2string wsize) (sign2string sign)
  | Owi2 (_sign, wsize, WIeq ) -> Format.sprintf "%s.eq" (size2string wsize)
  | Owi2 (_sign, wsize, WIneq) -> Format.sprintf "%s.ne" (size2string wsize)
  | Owi2 ( sign, wsize, WIlt ) -> Format.sprintf "%s.lt_%s" (size2string wsize) (sign2string sign)
  | Owi2 ( sign, wsize, WIle ) -> Format.sprintf "%s.le_%s" (size2string wsize) (sign2string sign)
  | Owi2 ( sign, wsize, WIgt ) -> Format.sprintf "%s.gt_%s" (size2string wsize) (sign2string sign)
  | Owi2 ( sign, wsize, WIge ) -> Format.sprintf "%s.ge_%s" (size2string wsize) (sign2string sign)
  | Obeq
  | Oand
  | Oor
  | Ovadd _
  | Ovsub _
  | Ovmul _
  | Ovlsr _
  | Ovlsl _
  | Ovasr _ -> expr2error expr

let exprs2string ?(break = true) ~(funname : string) ~(loc : error_loc) (es : 'len gexprs) : string =
  es
  |> List.map (expr2string ~funname ~loc)
  |> List.map (Format.sprintf (if break then "%s@." else "%s "))
  |> List.fold_left ( ^ ) ""

(* -------------------------------------------------------------------- *)

let fresh_block_name =
  let cpt = ref ~-1 in
  fun () ->
    incr cpt;
    Format.sprintf "#block_%d" !cpt

let fresh_loop_name =
  let cpt = ref ~-1 in
  fun () ->
    incr cpt;
    Format.sprintf "#loop_%d" !cpt

let set_pushed_values ~(funname : string) ~(loc : error_loc) ~(instr : ('len, 'info, 'asm) ginstr) (glvals : 'len glvals) : string =
  let instr2error = instr2error ~funname ~loc in
  let expr2string = expr2string ~funname ~loc in

  glvals
  |> List.map (
      fun (glval : 'len glval) ->
         match glval with
         | Lnone _ -> "(drop)"
         | Lvar igvar -> Format.sprintf "(%s.set $%s)" (igvar_kind2string igvar) (igvar_name igvar)
         | Lmem (_aligned, wsize, _info, addr) -> Format.sprintf "(%s.store %s)" (size2string wsize) (expr2string addr)
         | _ -> instr2error instr
     )
  |> List.rev
  |> List.fold_left (Format.sprintf "%s@.%s") ""

let rec instr2string ~(funname : string) ({ i_desc ; i_loc ; _ } as instr : ('len, 'info, 'asm) ginstr) : string =
  let loc = Lmore i_loc in
  let instrs2string = instrs2string ~funname in
  let instr2error = instr2error ~funname ~loc in
  let expr2string = expr2string ~funname ~loc in
  let exprs2string = exprs2string ~funname ~loc in
  let size2string = size2string ~funname ~loc in
  let set_pushed_values = set_pushed_values ~funname ~loc ~instr in

  match i_desc with
  | Cassgn (Lnone _, _tag, _gtype, expr) ->
    Format.sprintf "(%s)@.(drop)" (expr2string expr)
  | Cassgn (Lvar var, _tag, _gtype, expr) ->
    Format.sprintf "(%s.set $%s %s)" (igvar_kind2string var) (igvar_name var) (expr2string expr)
  | Cassgn (Lmem (_aligned, wsize, _info, addr), _tag, _gtype, expr) ->
    Format.sprintf "(%s.store %s %s)" (size2string wsize) (expr2string addr) (expr2string expr)
  | Cif (expr, then_instrs, else_instrs) ->
      Format.sprintf "(if %s@.(then@.%s)@.(else@.%s))" (expr2string expr) (instrs2string then_instrs) (instrs2string else_instrs)
  | Cwhile (_align, do_instrs, cond, _info, while_instrs) ->
    let block_name = fresh_block_name () in
    let loop_name = fresh_loop_name () in

    let do_instrs = instrs2string do_instrs in
    let while_instrs = instrs2string while_instrs in

    let cond = expr2string cond in

    Format.sprintf
    "(block $%s@.\
      (loop $%s@.\
        %s@.\
        (if %s@.\
          (then@.\
            %s@.\
            (br $%s)@.\
          )@.\
          (else@.\
            (br $%s)@.\
          )@.\
        )@.\
      )@.\
    )" block_name loop_name do_instrs cond while_instrs loop_name block_name
  | Ccall (glvals, funname_call, args) ->
    let name = funname_call.fn_name in
    let args = exprs2string ~break:false args in
    let call = Format.sprintf "(call $%s %s)" name args in
    let sets = set_pushed_values glvals in
    Format.sprintf "%s@.%s" call sets
  | Copn (_glvals, _tag, Opseudo_op Onop, _es) -> ""
  | Copn (([_; _] as glvals), _tag, Opseudo_op (Oswap _), ([_; _] as es)) ->
    Format.sprintf "%s%s@." (exprs2string es) (set_pushed_values (List.rev glvals))
  | Cassgn _
  | Copn _
  | Csyscall _
  | Cassert _
  | Cfor _ -> instr2error instr

and instrs2string ~(funname : string) (instrs : ('len, 'info, 'asm) ginstr list) : string =
  instrs
  |> List.map (instr2string ~funname)
  |> List.map (Format.sprintf "%s@.")
  |> List.fold_left ( ^ ) ""

(* -------------------------------------------------------------------- *)

let init_rip ?funname ?loc (locals : 'len gvar list) ~(rip_addr : Z.t) ~(rip : 'len gvar) : string =
  let type2string = type2string ?funname ?loc in

  let find_rip = List.exists (fun var -> GV.compare var rip = 0) locals in
  if not find_rip then ""
  else Format.sprintf "(local.set $%s (%s.const %s))" (gvar_name rip) (type2string (gvar_type rip)) (z2string rip_addr)

let init_rsp ?funname ?loc (locals : 'len gvar list) ~(rsp_addr : Z.t) ~(rsp : 'len gvar) : string =
  let type2string = type2string ?funname ?loc in

  let find_rsp = List.exists (fun var -> GV.compare var rsp = 0) locals in
  if not find_rsp then ""
  else Format.sprintf "(local.set $%s (%s.const %s))" (gvar_name rsp) (type2string (gvar_type rsp)) (z2string rsp_addr)

let compile_func ~(rsp_addr : Z.t) ~(rip_addr : Z.t) ~(rsp : 'len gvar) ~(rip : 'len gvar) ((_extra, func) : ('info, 'asm) sfundef) : string * string =
  let loc = Lone func.f_loc in
  let funname = func.f_name.fn_name in
  let locals = func |> Prog.locals |> Sv.to_list in

  let init_rip = init_rip ~funname ~loc in
  let init_rsp = init_rsp ~funname ~loc in
  let type2string = type2string ~funname ~loc in

  let def_name = funname in

  let def_params =
    func.f_args
    |> List.map (
         fun gvar ->
           Format.sprintf "(param $%s %s) " (gvar_name gvar) (type2string (gvar_type gvar))
       )
    |> List.fold_left ( ^ ) ""
  in

  let def_return_type =
    if List.is_empty func.f_tyout then ""
    else begin
      func.f_tyout
      |> List.map (
           fun gtype ->
             Format.sprintf "%s " (type2string gtype)
         )
      |> List.fold_left ( ^ ) ""
      |> Format.sprintf "(result %s)"
    end
  in

  let def_locals =
    locals
    |> List.map (
         fun gvar ->
           Format.sprintf "(local $%s %s)" (gvar_name gvar) (type2string (gvar_type gvar))
       )
    |> List.map (Format.sprintf "%s@.")
    |> List.fold_left ( ^ ) ""
  in

  let def_body =
    let rip = init_rip locals ~rip_addr ~rip in
    let rsp = init_rsp locals ~rsp_addr ~rsp in
    let instrs =  instrs2string ~funname func.f_body in
    Format.sprintf "%s@.%s@.%s" rip rsp instrs
  in

  let def_return =
    if List.is_empty func.f_ret then ""
    else begin
      func.f_ret
      |> List.map (
           fun igvar ->
             Format.sprintf "(%s.get $%s) " (igvar_kind2string igvar) (igvar_name igvar)
         )
      |> List.fold_left ( ^ ) ""
      |> Format.sprintf "(return %s)"
    end
  in

  let def = Format.sprintf "(func $%s %s %s@.%s@.%s@.%s@.)" def_name def_params def_return_type def_locals def_body def_return in
  let export = if FInfo.is_export func.f_cc then Format.sprintf {|(export "%s" (func $%s))|} def_name def_name else "" in
  (def, export)

let compile_funcs ~(rsp_addr : Z.t) ~(rsp : 'len gvar) ~(rip_addr : Z.t) ~(rip : 'len gvar) (p_funcs : ('info, 'asm) sfundef list) : string * string =
  let _rsp_addr, defs, exports =
    List.fold_left (
      fun (rsp_addr, defs, exports) ((extra, _func) as p_funcs) ->
        let (def, export) = compile_func ~rsp_addr ~rsp ~rip_addr ~rip p_funcs in

        let rsp_addr = rsp_addr +@ cz2z extra.sf_stk_sz in
        let defs = def :: defs in
        let exports = export :: exports in

        (rsp_addr, defs, exports)
    ) (rsp_addr, [], []) p_funcs
  in

  let defs = defs |> List.map (Format.sprintf "%s@.") |> List.fold_left (fun acc def -> def ^ acc) "" in
  let exports = exports |> List.map (Format.sprintf "%s@.") |> List.fold_left (fun acc export -> export ^ acc) "" in
  (defs, exports)

(* -------------------------------------------------------------------- *)

let get_memory ~(env : string) ~(memory : string) ~(page : int) : string =
  Format.sprintf {|(import "%s" "%s" (memory %d))|} env memory page

(* -------------------------------------------------------------------- *)

let compile_glob ~(rip_addr : Z.t) ~(rip : 'len gvar) (idx : int) (sp_glob : Word.word) : string =
  let rip_type = gvar_type rip in

  if rip_type <> Bty (U U32) then raise_dummy_error "Don't know how to handle RIP of this type %s" (type2error rip_type)
  else begin
    let gtype = type2string rip_type in
    Format.sprintf "(%s.store8 (%s.const %s) (%s.const %s))" gtype gtype (z2string (rip_addr +@ Z.of_int idx)) gtype (cz2string sp_glob)
  end

let compile_globs ~(rip_addr : Z.t) ~(rip : 'len gvar) (sp_globs : Word.word list) : Z.t * bool * string =
  let rsp_addr = rip_addr +@ Z.of_int (List.length sp_globs) in
  let should_init = Z.compare rip_addr rsp_addr <> 0 in

  let globs =
    sp_globs
    |> List.mapi (compile_glob ~rip_addr ~rip)
    |> List.map (Format.sprintf "%s@.")
    |> List.fold_left ( ^ ) ""
  in

  (rsp_addr, should_init, globs)

(* -------------------------------------------------------------------- *)

let get_init ~(should_init : bool) ~(init_name : string) (globs : string) : string =
  if should_init then Format.sprintf "(func $%s@.%s@.)" init_name globs else ""

(* -------------------------------------------------------------------- *)

let get_start ~(should_init : bool) ~(init_name : string) : string =
  if should_init then Format.sprintf "(start $%s)" init_name else ""

(* -------------------------------------------------------------------- *)

let compile_prog ~(rip_addr : Z.t) ~(init_name : string) (funcs : ('info, 'asm) sfundef list) ({ sp_rsp ; sp_rip ; sp_globs ; _ } : E.sprog_extra) : string =
  let rsp = sp_rsp in
  let rip = sp_rip in

  let compiled_memory = get_memory ~env:"env" ~memory:"memory" ~page:1 in
  let (rsp_addr, should_init, compiled_globs) = compile_globs ~rip_addr ~rip sp_globs in
  let compiled_funcs, compiled_exports = compile_funcs ~rsp_addr ~rip_addr ~rsp ~rip funcs in
  let compiled_init = get_init ~should_init ~init_name compiled_globs in
  let compiled_start = get_start ~should_init ~init_name in

  Format.sprintf {|@.(module@.%s@.%s@.%s@.%s@.%s@.)@.|} compiled_memory compiled_funcs compiled_init compiled_exports compiled_start

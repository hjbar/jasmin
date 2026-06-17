open Prog
open Wasm_utils

(* -------------------------------------------------------------------- *)

let wsize_to_gty (wsize : Wsize.wsize) : 'len gty =
  Bty (U wsize)

let ( <=@ ) ws1 ws2 =
  let open Wsize in

  match ws1, ws2 with
  | U8, _ -> true
  | U16, U8 -> false
  | U16, _ -> true
  | U32, (U8 | U16) -> false
  | U32, _ -> true
  | U64, (U8 | U16 | U32) -> false
  | U64, _ -> true
  | U128, (U8 | U16 | U32 | U64) -> false
  | U128, _ -> true
  | U256, (U8 | U16 | U32 | U64 | U128) -> false
  | U256, _ -> true

(* -------------------------------------------------------------------- *)

let simplify : 'len gexpr -> 'len gexpr = function
  | Papp1 (Ozeroext (desired, base), Papp1 (Oword_of_int base', Pconst z)) when base = base' && desired <=@ base ->
    Papp1 (Oword_of_int desired, Pconst z)
  | Papp1 (Ozeroext (desired, base), Papp1 (Ozeroext (desired', base'), expr)) when base = desired' && desired <=@ base' ->
    Papp1 (Ozeroext (desired, base'), expr)
  | Papp1 (Oword_of_int desired, Papp1 (Oint_of_word (_sign, base), expr)) when desired = base ->
    expr
  | _ as expr -> expr

let ext_op ~(desired : 'len gty) ~(base : 'len gty) (expr : 'len gexpr) : 'len gexpr =
  match desired, base with
  | Bty desired, Bty base -> begin
    match desired, base with
    | Bool, Bool
    | Int, Int
    | U U8, U U8
    | U U16, U U16
    | U U32, U U32
    | U U64, U U64
    | U U128, U U128
    | U U256, U U256 -> expr
    | U desired, U base -> simplify (Papp1 (Ozeroext (desired, base), expr))
    | U desired, Int -> simplify (Papp1 (Oword_of_int desired, expr))
    | _, _ -> assert false
  end
  | Arr (ws1, len1), Arr (ws2, len2) when ws1 = ws2 && len1 = len2 -> expr
  | _, _ -> assert false

(* -------------------------------------------------------------------- *)

let rec explicit_expr (desired : 'len gty) : 'len gexpr -> 'len gexpr = function
  | Pconst _z as expr ->
    let base = Bty Int in

    ext_op ~desired ~base expr
  | Pvar ggvar as expr ->
    let base = ggvar.gv.pl_desc.v_ty in

    ext_op ~desired ~base expr
  | Pget (aligned, access, wsize, ggvar, index) as expr ->
    let base = Typing.ty_expr pointer_data Location.i_dummy expr in
    let index = explicit_expr (Bty (U pointer_data)) index in

    ext_op ~desired ~base (Pget (aligned, access, wsize, ggvar, index))
  | Psub (access, wsize, len, ggvar, index) as expr ->
    let base = Typing.ty_expr pointer_data Location.i_dummy expr in
    let index = explicit_expr (Bty (U pointer_data)) index in

    ext_op ~desired ~base (Psub (access, wsize, len, ggvar, index))
  | Pload (aligned, wsize, addr) ->
    let base = wsize_to_gty wsize in
    let addr = explicit_expr (wsize_to_gty pointer_data) addr in

    ext_op ~desired ~base (Pload (aligned, wsize, addr))
  | Papp1 (op, expr) ->
    let ty_in, base = Typing.type_of_op1 op in
    let expr = explicit_expr ty_in expr in

    ext_op ~desired ~base (Papp1 (op, expr))
  | Papp2 (op, e1, e2) ->
    let (ty_in1, ty_in2), base = Typing.type_of_op2 op in
    let e1 = explicit_expr ty_in1 e1 in
    let e2 = explicit_expr ty_in2 e2 in

    ext_op ~desired ~base (Papp2 (op, e1, e2))
  | PappN (op, es) ->
    let tys_in, base = Typing.type_of_opN op in
    let es = explicit_exprs tys_in es in

    ext_op ~desired ~base (PappN (op, es))
  | Pif (base, cond, then_, else_) ->
    let cond = explicit_expr tbool cond in
    let then_ = explicit_expr base then_ in
    let else_ = explicit_expr base else_ in

    ext_op ~desired ~base (Pif (base, cond, then_, else_))
  | Pbool _
  | Parr_init _ -> assert false

and explicit_exprs (gtys : 'len gty list) (es : 'len gexpr list) : 'len gexpr list =
  List.map2 explicit_expr gtys es

(* -------------------------------------------------------------------- *)

let explicit_glval : 'len glval -> 'len glval = function
  | Lnone _
  | Lvar _ as glval -> glval
  | Lmem (align, wsize, loc, addr) ->
    let addr = explicit_expr (wsize_to_gty pointer_data) addr in
    Lmem (align, wsize, loc, addr)
  | Laset (align, access, wsize, igvar, index) ->
    let index = explicit_expr (Bty (U pointer_data)) index in
    Laset (align, access, wsize, igvar, index)
  | Lasub (access, wsize, len, igvar, gexpr) ->
    let gexpr = explicit_expr (Bty (U pointer_data)) gexpr in
    Lasub (access, wsize, len, igvar, gexpr)

let explicit_glvals (glvals : 'len glval list) : 'len glval list =
  List.map explicit_glval glvals

(* -------------------------------------------------------------------- *)

let rec explicit_instr (ht : (funname, (int, unit, 'asm) gfunc) Hashtbl.t) ({ i_desc ; i_loc ; _ } as instr : ('len, 'info, 'asm) ginstr) : ('len, 'info, 'asm) ginstr =
  let explicit_instrs = explicit_instrs ht in

  let i_desc =
    match i_desc with
    | Cassgn (glval, tag, gty, expr) ->
      let glval = explicit_glval glval in
      let expr = explicit_expr gty expr in
      Cassgn (glval, tag, gty, expr)
    | Cif (cond, then_, else_) ->
      let cond = explicit_expr tbool cond in
      let then_ = explicit_instrs then_ in
      let else_ = explicit_instrs else_ in
      Cif (cond, then_, else_)
    | Cwhile (align, do_, cond, info, while_) ->
      let cond = explicit_expr tbool cond in
      let do_ = explicit_instrs do_ in
      let while_ = explicit_instrs while_ in
      Cwhile (align, do_, cond, info, while_)
    | Ccall (glvals, funname, args) ->
      let glvals = explicit_glvals glvals in
      let tys_in = (Hashtbl.find ht funname).f_tyin in
      let args = explicit_exprs tys_in args in
      Ccall (glvals, funname, args)
    | Copn (glvals, tag, op, es) ->
      let glvals = explicit_glvals glvals in
      let tys_in, _ = Typing.type_of_sopn i_loc pointer_data Arch.msf_size Arch.asmOp op in
      let es = explicit_exprs tys_in es in
      Copn (glvals, tag, op, es)
    | Csyscall (glvals, syscall, es) ->
      let glvals = explicit_glvals glvals in
      let s = Syscall.syscall_sig_s pointer_data syscall in
      let tys_in = List.map Conv.ty_of_cty s.scs_tin in
      let es = explicit_exprs tys_in es in
      Csyscall (glvals, syscall, es)
    | Cassert _
    | Cfor _ -> assert false
  in
  { instr with i_desc }

and explicit_instrs (ht : (funname, (int, unit, 'asm) gfunc) Hashtbl.t) (instrs : ('len, 'info, 'asm) ginstr list) : ('len, 'info, 'asm) ginstr list =
  List.map (explicit_instr ht) instrs

(* -------------------------------------------------------------------- *)

let explicit_func (ht : (funname, (int, unit, 'asm) gfunc) Hashtbl.t) ((extra, func) : ('info, 'asm) sfundef) : ('info, 'asm) sfundef =
  (extra, { func with f_body = explicit_instrs ht func.f_body })

let explicit_funcs (ht : (funname, (int, unit, 'asm) gfunc) Hashtbl.t) (funcs : ('info, 'asm) sfundef list) : ('info, 'asm) sfundef list =
  List.map (explicit_func ht) funcs

(* -------------------------------------------------------------------- *)

let make_explicit ((funcs, extra) : (unit, 'asm) sprog) : (unit, 'asm) sprog =
  let ht = Hashtbl.create 16 in
  List.iter (fun (_extra, func) -> Hashtbl.replace ht func.f_name func) funcs;
  explicit_funcs ht funcs, extra

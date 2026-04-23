open Utils
open Prog
open Glob_options
open Wasm_ast

(* -------------------------------------------------------------------- *)

let rec all_equal : 'a list -> bool = function
  | []
  | [ _ ] -> true
  | x :: y :: l -> x = y && all_equal (y :: l)

(* -------------------------------------------------------------------- *)

let rec has_randombytes_i i =
  match i.i_desc with
  | Csyscall (_, RandomBytes _, _) -> true
  | Cassgn _ | Copn _ | Ccall _ | Cassert _ -> false
  | Cif (_, c1, c2) | Cwhile(_, c1, _, _, c2) -> has_randombytes_c c1 || has_randombytes_c c2
  | Cfor (_, _, c) -> has_randombytes_c c

and has_randombytes_c c = List.exists has_randombytes_i c

let has_randombytes_f (_, f) = has_randombytes_c f.f_body

let has_randombytes_fs fs = List.exists has_randombytes_f fs

(* -------------------------------------------------------------------- *)

module Core = CoreArchFactory.Core_arch_WASM
module Arch = Arch_full.Arch_from_Core_arch_wasm (Core)
let pointer_data = Arch.pointer_data

(* -------------------------------------------------------------------- *)

let dummy_randombytes : (Wsize.wsize * BinNums.positive) Syscall_t.syscall_t = Syscall_t.RandomBytes (U8, Conv.pos_of_int 1)

let randombytes_funname : funname = CoreIdent.F.mk (Asm_utils.pp_syscall dummy_randombytes)

(* -------------------------------------------------------------------- *)

let internal_error = hierror ~loc:Lnone ~kind:"compilation internal error" ~internal:true

(* -------------------------------------------------------------------- *)

let ( +@ ) = Z.add

let ( -@ ) = Z.sub

let ( <<@ ) = Z.shift_left

let ( %@ ) = Z.erem

let minus_one = Z.of_int ~-1

let zero = Z.of_int 0

let one = Z.of_int 1

(* -------------------------------------------------------------------- *)

let check_ty = function
  | I32 | I64 | V128 -> ()
  | _ -> internal_error "Type should be i32, i64 or v128"

let check_tys = List.iter check_ty

let check_int_ty = function
  | I32 | I64 -> ()
  | _ -> internal_error "Type should be i32 or i64"

let check_vec_ty = function
  | V128 -> ()
  | _ -> internal_error "Type should be v128"

let check_simd_ty = function
  | Simd _ -> ()
  | _ -> internal_error "Type should be i8x16, i16x8, i32x4 or i64x2"

let check_size_simd simd_ty nums =
  let rec is_length_aux d nums =
    match nums with
    | [] -> d = 0
    | _ :: nums ->
      if d <= 0 then false
      else is_length_aux (d - 1) nums
  in

  let is_length d =
    if not (is_length_aux d nums) then
      internal_error "List of wrong size"
  in

  check_simd_ty simd_ty;

  match simd_ty with
  | Simd I8x16 -> is_length 16
  | Simd I16x8 -> is_length 8
  | Simd I32x4 -> is_length 4
  | Simd I64x2 -> is_length 2
  | _ -> assert false

let check_extract_simd = function
  | Simd (I32x4 | I64x2) -> ()
  | _ -> internal_error "Wrong simd type to extract vector lanes"

let check_in_bounds simd_ty num =
  check_simd_ty simd_ty;

  match simd_ty with
  | Simd I8x16 -> if Z.lt num zero || Z.gt num (Z.of_int 15) then internal_error "Indice should be between 0 and 15 to access the i8x16 vector"
  | Simd I16x8 -> if Z.lt num zero || Z.gt num (Z.of_int 7) then internal_error "Indice should be between 0 and 7 to access the i16x8 vector"
  | Simd I32x4 -> if Z.lt num zero || Z.gt num (Z.of_int 3) then internal_error "Indice should be between 0 and 3 to access the i32x4 vector"
  | Simd I64x2 -> if Z.lt num zero || Z.gt num (Z.of_int 1) then internal_error "Indice should be between 0 and 1 to access the i64x2 vector"
  | _ -> assert false

let check_non_empty = function
  | [] -> internal_error "List should be non empty"
  | _ -> ()

let check_max_size int_ty size =
  check_int_ty int_ty;

  match int_ty, size with
  | I32, (U8 | U16) -> ()
  | I64, (U8 | U16 | U32) -> ()
  | I32, _ | I64, _ -> internal_error "Size should be smaller"
  | _ -> assert false

(* -------------------------------------------------------------------- *)

let extract_ simd_ty num =
  check_extract_simd simd_ty;
  check_in_bounds simd_ty num;
  Extract (simd_ty, num)

let const_num_ int_ty num =
  check_int_ty int_ty;
  Const (int_ty, None, [ num ])

let const_vec_ vec_ty simd_ty nums =
  check_vec_ty vec_ty;
  check_simd_ty simd_ty;
  check_size_simd simd_ty nums;
  Const (vec_ty, Some simd_ty, nums)

let set_ scope var instr =
  Set (scope, var, Some instr)

let set_stack_ scope var =
  Set (scope, var, None)

let load_ ty instr =
  check_ty ty;
  Load (ty, None, None, instr)

let load_size_ int_ty size sign instr =
  check_int_ty int_ty;
  check_max_size int_ty size;
  Load (int_ty, Some size, Some sign, instr)

let store_ ty addr instr =
  check_ty ty;
  Store (ty, None, addr, Some instr)

let store_stack_ ty addr =
  check_ty ty;
  Store (ty, None, addr, None)

let store_size_ int_ty size addr instr =
  check_int_ty int_ty;
  check_max_size int_ty size;
  Store (int_ty, Some size, addr, Some instr)

let if_ cond then_ else_ =
  If ([], cond, then_, else_)

let if_result_ res cond then_ else_ =
  check_non_empty res;
  check_tys res;
  If (res, cond, [ then_ ], [ else_ ])

(* -------------------------------------------------------------------- *)

let cz_to_z = Conv.z_of_cz

let gvar_name (gvar : 'len gvar) : name =
  gvar.v_name

let gvar_uid (gvar : 'len gvar) : uid =
  gvar.v_id

let gvar_type (gvar : 'len gvar) : 'len gty =
  gvar.v_ty

let gvar_is_glob (gvar : 'len gvar) : bool =
  gvar.v_kind = Global

(* -------------------------------------------------------------------- *)

let size_to_doc : size -> string = function
  | U8   -> "U8"
  | U16  -> "U16"
  | U32  -> "U32"
  | U64  -> "U64"

let wsize_to_doc : Wsize.wsize -> string = function
  | U8   -> "U8"
  | U16  -> "U16"
  | U32  -> "U32"
  | U64  -> "U64"
  | U128 -> "U128"
  | U256 -> "U256"

let type_to_doc : 'len gty -> string = function
  | Bty Bool -> "bool"
  | Bty Int -> "int"
  | Bty (U wsize) -> Format.sprintf "word(%s)" (wsize_to_doc wsize)
  | Arr (wsize, len) -> Format.sprintf "arr(%s, %s)" (wsize_to_doc wsize) (string_of_int len)

let op_kind_to_doc : Operators.op_kind -> string = function
  | Op_int -> "op_int"
  | Op_w wsize -> Format.sprintf "op_w(%s)" (wsize_to_doc wsize)

let sign_to_doc : Wsize.signedness -> string = function
  | Signed -> "signed"
  | Unsigned -> "unsigned"

let cmp_kind_to_doc : Operators.cmp_kind -> string = function
  | Cmp_int -> "cmp_int"
  | Cmp_w (sign, wsize) -> Format.sprintf "cmp_w(%s, %s)" (sign_to_doc sign) (wsize_to_doc wsize)

(* -------------------------------------------------------------------- *)

let raise_error ?(loc : error_loc = Lnone) ?(kind = "compilation error") ?(sub_kind = "Stack Allocation to Wasm") ?(internal = false) ~funname msg =
  let funname = funname.fn_name in
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

let size_to_error ?funname ?loc (size : size) =
  raise_error_opt ?funname ?loc "Don't know how to handle this size %s" (size_to_doc size)

let wsize_to_error ?funname ?loc (wsize : Wsize.wsize) =
  raise_error_opt ?funname ?loc "Don't know how to handle this wsize %s" (wsize_to_doc wsize)

let gty_to_error ?funname ?loc (gtype : 'len gty) =
  raise_error_opt ?funname ?loc "Don't know how to handle this type %s" (type_to_doc gtype)

let op_kind_to_error ?funname ?loc (op_kind : Operators.op_kind) =
  raise_error_opt ?funname ?loc "Don't know how to handle this kind of op %s" (op_kind_to_doc op_kind)

let cmp_kind_to_error ?funname ?loc (cmp_kind : Operators.cmp_kind) =
  raise_error_opt ?funname ?loc "Don't know how to handle this kind of cmp %s" (cmp_kind_to_doc cmp_kind)

let gexpr_to_error ~(funname : funname) ~(loc : error_loc) (expr : 'len gexpr) =
  let debug = !debug in
  raise_error ~loc ~funname "Don't know how to handle the expression %a" (Printer.pp_expr ~debug) expr

let ginstr_to_error ~(funname : funname) ~(loc : error_loc) (instr : ('len, 'info, 'asm) ginstr) =
  let debug = !debug in
  raise_error ~loc ~funname "Don't know how to handle the instruction %a" (Printer.pp_instr ~debug pointer_data Arch.msf_size Arch.asmOp) instr

(* -------------------------------------------------------------------- *)

let z_to_num : Z.t -> num = Fun.id

let cz_to_num (cz : BinNums.coq_Z) : num = cz |> Conv.z_of_cz |> z_to_num

let size_to_num (size : size) : num =
  let n =
    match size with
    | U8 -> 8
    | U16 -> 16
    | U32 -> 32
    | U64 -> 64
  in
  Z.of_int n

let size_to_int_ty ?funname ?loc : size -> ty = function
  | U32 -> I32
  | U64 -> I64
  | _ as size -> size_to_error ?funname ?loc size

let wsize_to_size ?funname ?loc : Wsize.wsize -> size = function
  | U8 -> U8
  | U16 -> U16
  | U32 -> U32
  | U64 -> U64
  | _ as wsize -> wsize_to_error ?funname ?loc wsize

let op_kind_to_size ?funname ?loc : Operators.op_kind -> size = function
  | Op_w wsize -> wsize_to_size ?funname ?loc wsize
  | Op_int as op_kind -> op_kind_to_error ?funname ?loc op_kind

let wsize_to_int_ty ?funname ?loc : Wsize.wsize -> ty = function
  | U32 -> I32
  | U64 -> I64
  | _ as wsize -> wsize_to_error ?funname ?loc wsize

let wsize_to_vec_ty ?funname ?loc : Wsize.wsize -> ty = function
  | U128 -> V128
  | _ as wsize -> wsize_to_error ?funname ?loc wsize

let wsize_to_ty ?funname ?loc : Wsize.wsize -> ty = function
  | U32 -> I32
  | U64 -> I64
  | U128 -> V128
  | _ as wsize -> wsize_to_error ?funname ?loc wsize

let wsize_to_op_ty ?funname ?loc : Wsize.wsize -> ty = function
  | U32 -> I32
  | U64 -> I64
  | U128 -> V128
  | _ as wsize -> wsize_to_error ?funname ?loc wsize

let gty_to_int_ty ?funname ?loc : 'len gty -> ty = function
  | Bty (U wsize) -> wsize_to_int_ty ?funname ?loc wsize
  | Bty Bool
  | Bty Int
  | Arr _ as gtype -> gty_to_error ?funname ?loc gtype

let gty_to_ty ?funname ?loc : 'len gty -> ty = function
  | Bty (U wsize) -> wsize_to_ty ?funname ?loc wsize
  | Bty Bool
  | Bty Int
  | Arr _ as gtype -> gty_to_error ?funname ?loc gtype

let gvar_to_var ?funname ?loc (gvar : 'len gvar) : var =
  let var_name = gvar_name gvar in
  let var_uid = gvar_uid gvar in
  let var_ty = gvar |> gvar_type |> gty_to_ty ?funname ?loc in
  { var_name ; var_uid ; var_ty }

let igvar_to_var ?funname ?loc (gvar_i : 'len gvar_i) : var =
  gvar_to_var ?funname ?loc gvar_i.pl_desc

let ggvar_to_var ?funname ?loc (ggvar : 'len ggvar) : var =
  igvar_to_var ?funname ?loc ggvar.gv

let gvar_to_scope (gvar : 'len gvar) : scope =
  if gvar_is_glob gvar then Sglob else Slocal

let igvar_to_scope (gvar_i : 'len gvar_i) : scope =
  gvar_to_scope gvar_i.pl_desc

let ggvar_to_scope (ggvar : 'len ggvar) : scope =
  igvar_to_scope ggvar.gv

let op_kind_to_int_ty ?funname ?loc : Operators.op_kind -> ty = function
  | Op_w wsize -> wsize_to_int_ty ?funname ?loc wsize
  | Op_int as op_kind -> op_kind_to_error ?funname ?loc op_kind

let op_kind_to_op_ty ?funname ?loc : Operators.op_kind -> ty = function
  | Op_w wsize -> wsize_to_op_ty ?funname ?loc wsize
  | Op_int as op_kind -> op_kind_to_error ?funname ?loc op_kind

let cmp_kind_to_wasm ?funname ?loc : Operators.cmp_kind -> ty * sign = function
  | Cmp_w (sign, wsize) -> (op_kind_to_int_ty ?funname ?loc (Op_w wsize), sign)
  | Cmp_int as cmp_kind -> cmp_kind_to_error ?funname ?loc cmp_kind

let velem_to_op_ty : Wsize.velem -> ty = function
  | VE8  -> Simd I8x16
  | VE16 -> Simd I16x8
  | VE32 -> Simd I32x4
  | VE64 -> Simd I64x2

let velem_to_size : Wsize.velem -> size = function
  | VE8  -> U8
  | VE16 -> U16
  | VE32 -> U32
  | VE64 -> U64

(* -------------------------------------------------------------------- *)

let is_word_op_ext : Operators.sop1 -> bool = function
  | Osignext (U32, U64)
  | Ozeroext (U32, U64)
  | Osignext (U64, U32)
  | Ozeroext (U64, U32) -> true
  | _ -> false

let op_ext_to_wasm : Operators.sop1 -> unop = function
  | Osignext (U32, U64)
  | Ozeroext (U32, U64) -> Wrap
  | Osignext (U64, U32) -> Extend Signed
  | Ozeroext (U64, U32) -> Extend Unsigned
  | _ -> assert false

(* -------------------------------------------------------------------- *)

let is_load_op_ext : Operators.sop1 -> bool = function
  | Osignext ((U32 | U64), (U8 | U16))
  | Ozeroext ((U32 | U64), (U8 | U16)) -> true
  | _ -> false

let get_op_ext_sizes : Operators.sop1 -> Wsize.wsize * Wsize.wsize = function
  | Osignext (desired, base)
  | Ozeroext (desired, base) -> (desired, base)
  | _ -> assert false

let get_op_ext_sign : Operators.sop1 -> sign = function
  | Osignext _ -> Signed
  | Ozeroext _ -> Unsigned
  | _ -> assert false

(* Check: op_ext in { Osignext, Ozeroext } && sizes(op_ext) = (desired, base) && desired in { U32, U64 } && base in { U8, U16 } && base = load_size *)
let is_load_size (op_ext : Operators.sop1) (load_size : Wsize.wsize) : bool =
  if not (is_load_op_ext op_ext) then false
  else begin
    let (desired, base) = get_op_ext_sizes op_ext in
    (desired = U32 || desired = U64) &&
    (base = U8 || base = U16) &&
    (base = load_size)
  end

(* -------------------------------------------------------------------- *)

let is_shift : Operators.sop2 -> bool = function
  | Olsl _
  | Olsr _
  | Oasr _
  | Orol _
  | Oror _ -> true
  | _ -> false

let get_shift_size : Operators.sop2 -> size = function
  | Olsl op
  | Oasr op -> op_kind_to_size op
  | Olsr wsize
  | Orol wsize
  | Oror wsize -> wsize_to_size wsize
  | _ -> assert false

let is_mod (op : Operators.sop2) (z : Z.t) : bool =
  let desired = (op |> get_shift_size |> size_to_num) -@ one in
  desired = z

(* Check: (op in { lsl ; lsr; asr; rol; ror }) && (size(op) = 32 || size(op) = 64) *)
let is_shift_const (op : Operators.sop2) : bool =
  if not (is_shift op) then false
  else begin
    let op_size = get_shift_size op in
    op_size = U32 || op_size = U64
  end

(* Check: (op in { lsl; lsr; asr; rol; ror }) && (size(op) = 32 || size(op) = 64) && (size(op) = ws1 = ws2 = ws3) && (z = size(op) - 1) *)
let is_shift_mod (op : Operators.sop2) (ws : Wsize.wsize list) (z : Z.t) : bool =
  if not (is_shift op) then false
  else begin
    let op_size = get_shift_size op in
    if op_size <> U32 && op_size <> U64 then false
    else begin
      let sizes = op_size :: List.map wsize_to_size ws in
      all_equal sizes && is_mod op z
    end
  end

let shift_to_wasm ?funname ?loc : Operators.sop2 -> binop = function
  | Olsl op -> Shl (op_kind_to_op_ty ?funname ?loc op)
  | Olsr wsize -> Shr (wsize_to_op_ty ?funname ?loc wsize, Unsigned)
  | Oasr op -> Shr (op_kind_to_op_ty ?funname ?loc op, Signed)
  | Orol wsize -> Rotl (wsize_to_int_ty ?funname ?loc wsize)
  | Oror wsize -> Rotr (wsize_to_int_ty ?funname ?loc wsize)
  | _ -> assert false

(* -------------------------------------------------------------------- *)

let is_vec_shift : Operators.sop2 -> bool = function
  | Ovlsl (_, U128)
  | Ovlsr (_, U128)
  | Ovasr (_, U128) -> true
  | _ -> false

let get_vec_shift_size : Operators.sop2 -> size = function
  | Ovlsl (velem, U128)
  | Ovlsr (velem, U128)
  | Ovasr (velem, U128) -> velem_to_size velem
  | _ -> assert false

let is_vec_mod (op : Operators.sop2) (z : Z.t) : bool =
  let desired = (op |> get_vec_shift_size |> size_to_num) -@ one in
  desired = z

(* Check: op in { vlsl: vlsr; vasr } && size(op) = 128 *)
let is_vec_shift_const (op : Operators.sop2) : bool =
  is_vec_shift op

(* Check: op in { vlsl; vlsr; vasr } && size(op) = 128 && shift_size(op) in { 8; 16; 32; 64 } && z = shift_size(op) - 1 *)
let is_vec_shift_mod (op : Operators.sop2) (z : Z.t) : bool =
  is_vec_shift op && is_vec_mod op z

let vec_shift_to_wasm : Operators.sop2 -> binop = function
  | Ovlsl (velem, U128) -> Shl (velem_to_op_ty velem)
  | Ovlsr (velem, U128) -> Shr (velem_to_op_ty velem, Unsigned)
  | Ovasr (velem, U128) -> Shr (velem_to_op_ty velem, Signed)
  | _ -> assert false

(* -------------------------------------------------------------------- *)

let rec gexpr_to_instr ~(funname : funname) ~(i_loc : Location.i_loc) (gexpr : 'len gexpr) : instr =
  let loc = Lmore i_loc in

  let gexpr_to_error = gexpr_to_error ~funname ~loc in

  let wsize_to_ty = wsize_to_ty ~funname ~loc in
  let gty_to_ty = gty_to_ty ~funname ~loc in
  let ggvar_to_var = ggvar_to_var ~funname ~loc in

  let gexpr_to_instr = gexpr_to_instr ~funname ~i_loc in
  let unop_to_instr = unop_to_instr ~funname ~i_loc in
  let binop_to_instr = binop_to_instr ~funname ~i_loc in

  match gexpr with
  | Pvar ggvar ->
    let scope = ggvar_to_scope ggvar in
    let var = ggvar_to_var ggvar in
    Get (scope, var)
  | Pload (_aligned, ((U32 | U64 | U128) as wsize), gexpr) ->
    let ty = wsize_to_ty wsize in
    let instr = gexpr_to_instr gexpr in
    load_ ty instr
  | Papp1 (op, expr) -> unop_to_instr op expr
  | Papp2 (op, e1, e2) -> binop_to_instr op e1 e2
  | Pif (gty, cond, then_, else_) ->
    let ty = gty_to_ty gty in
    let cond = gexpr_to_instr cond in
    let then_ = gexpr_to_instr then_ in
    let else_ = gexpr_to_instr else_ in
    if_result_ [ ty ] cond then_ else_
  | Pconst _
  | Pbool _
  | Pload _
  | Parr_init _
  | Pget _
  | Psub _
  | PappN _ -> gexpr_to_error gexpr

and unop_to_instr ~(funname : funname) ~(i_loc : Location.i_loc) (op : Operators.sop1) (gexpr : 'len gexpr) : instr =
  let loc = Lmore i_loc in

  let gexpr_to_error = gexpr_to_error ~funname ~loc in

  let wsize_to_size = wsize_to_size ~funname ~loc in
  let wsize_to_int_ty = wsize_to_int_ty ~funname ~loc in
  let wsize_to_ty = wsize_to_ty ~funname ~loc in
  let wsize_to_vec_ty = wsize_to_vec_ty ~funname ~loc in
  let op_kind_to_int_ty = op_kind_to_int_ty ~funname ~loc in
  let op_kind_to_op_ty = op_kind_to_op_ty ~funname ~loc in

  let gexpr_to_instr = gexpr_to_instr ~funname ~i_loc in

  match op, gexpr with
  (* Special cases on gexpr *)
  | Oword_of_int ((U32 | U64) as wsize), Pconst z ->
    let int_ty = wsize_to_int_ty wsize in
    let num = z_to_num z in
    const_num_ int_ty num
  | Oword_of_int (U128 as wsize), Pconst z ->
    let vec_ty = wsize_to_vec_ty wsize in
    let low = z_to_num (Z.extract z 0 64) in (* bits 0 to 63 *)
    let high = z_to_num (Z.extract z 64 64) in (* bits 64 to 127 *)
    const_vec_ vec_ty (Simd I64x2) [ low; high ]
  | op_ext, Pload (_aligned, load_size, gexpr) when is_load_size op_ext load_size ->
    (* Ensures: op_ext in { Osignext, Ozeroext } && sizes(op_ext) = (desired, base) && desired in { U32, U64 } && base in { U8, U16 } && base = load_size *)
    let (desired, base) = get_op_ext_sizes op_ext in

    let load_ty = wsize_to_ty desired in
    let load_size = wsize_to_size base in
    let sign = get_op_ext_sign op_ext in
    let instr = gexpr_to_instr gexpr in

    load_size_ load_ty load_size sign instr
  | _ ->
    match op with
    (* Special cases on op *)
    | Olnot ((U32 | U64) as wsize) ->
      let int_ty = wsize_to_int_ty wsize in
      let instr = gexpr_to_instr gexpr in
      let num = z_to_num minus_one in
      Binop (Xor int_ty, instr, const_num_ int_ty num)
    | Oneg op ->
      let op_ty = op_kind_to_op_ty op in
      let num = z_to_num zero in
      let int_ty = op_kind_to_int_ty op in
      let instr = gexpr_to_instr gexpr in
      Binop (Sub op_ty, const_num_ int_ty num, instr)
    (* Common cases *)
    | _ ->
      let unop =
        match op with
        | Olnot U128 -> Not
        | op_ext when is_word_op_ext op_ext -> op_ext_to_wasm op_ext
        | Oint_of_word _
        | Oword_of_int _
        | Olnot _
        | Onot
        | Oneg _
        | Osignext _
        | Ozeroext _
        | Owi1 _ -> gexpr_to_error (Papp1 (op, gexpr))
      in
      let instr = gexpr_to_instr gexpr in
      Unop (unop, instr)

and binop_to_instr ~(funname : funname) ~(i_loc : Location.i_loc) (op : Operators.sop2) (e1 : 'len gexpr) (e2 : 'len gexpr) : instr =
  let loc = Lmore i_loc in

  let gexpr_to_error = gexpr_to_error ~funname ~loc in

  let size_to_int_ty = size_to_int_ty ~funname ~loc in
  let wsize_to_ty = wsize_to_ty ~funname ~loc in
  let op_kind_to_int_ty = op_kind_to_int_ty ~funname ~loc in
  let cmp_kind_to_wasm = cmp_kind_to_wasm ~funname ~loc in
  let shift_to_wasm = shift_to_wasm ~funname ~loc in

  let gexpr_to_instr = gexpr_to_instr ~funname ~i_loc in

  match op, e1, e2 with
  (* Special cases *)
  | op, gexpr, Papp1 (Oword_of_int U8, Pconst z) when is_shift_const op ->
    (* Ensures: (op in { lsl ; lsr; asr; rol; ror }) && (size(op) = 32 || size(op) = 64) *)
    let shift_size = get_shift_size op in
    let int_ty = size_to_int_ty shift_size in

    let z = z %@ ((one <<@ 8) -@ one) in
    if Z.compare z (size_to_num shift_size) = -1 then
      let op = shift_to_wasm op in
      let instr = gexpr_to_instr gexpr in
      Binop (op, instr, const_num_ int_ty z)
    else
      const_num_ int_ty (z_to_num zero)
  | op, e1, Papp1 (Ozeroext (U8, ws1), Papp2 (Oland ws2, e2, Papp1 (Oword_of_int ws3, Pconst z))) when is_shift_mod op [ ws1; ws2; ws3 ] z ->
    (* Ensures: (op in { lsl; lsr; asr; rol; ror }) && (size(op) = 32 || size(op) = 64) && (size(op) = ws1 = ws2 = ws3) && (z = size(op) - 1) *)
    let op = shift_to_wasm op in
    let i1 = gexpr_to_instr e1 in
    let i2 = gexpr_to_instr e2 in
    Binop (op, i1, i2)
  | op, gexpr, Papp1 (Oword_of_int U128, Pconst z) when is_vec_shift_const op ->
    (* Ensures: op in { vlsl: vlsr; vasr } && size(op) = 128 *)
    let shift_size = get_vec_shift_size op in
    let int_ty = size_to_int_ty shift_size in

    let z = z %@ ((one <<@ 128) -@ one) in
    if Z.compare z (size_to_num shift_size) = -1 then
      let op = vec_shift_to_wasm op in
      let instr = gexpr_to_instr gexpr in
      Binop (op, instr, const_num_ int_ty z)
    else
      const_num_ int_ty (z_to_num zero)
  | op, e1, Papp2 (Oland U128, e2, Papp1 (Oword_of_int U128, Pconst z)) when is_vec_shift_mod op z ->
    (* Ensures: op in { vlsl; vlsr; vasr } && size(op) = 128 && shift_size(op) in { 8; 16; 32; 64 } && z = shift_size(op) - 1 *)
    let op = vec_shift_to_wasm op in
    let i1 = gexpr_to_instr e1 in
    let i2 = Unop (extract_ (Simd I32x4) (z_to_num zero), gexpr_to_instr e2) in
    Binop (op, i1, i2)
  (* Common cases *)
  | _ ->
    let binop =
      match op with
      | Oadd op -> Add (op_kind_to_int_ty op)
      | Osub op -> Sub (op_kind_to_int_ty op)
      | Omul op -> Mul (op_kind_to_int_ty op)
      | Odiv (sign, op) -> Div (op_kind_to_int_ty op, sign)
      | Omod (sign, op) -> Rem (op_kind_to_int_ty op, sign)
      | Oland wsize -> And (wsize_to_ty wsize)
      | Olor wsize -> Or (wsize_to_ty wsize)
      | Olxor wsize -> Xor (wsize_to_ty wsize)
      | Oeq op -> Eq (op_kind_to_int_ty op)
      | Oneq op -> Ne (op_kind_to_int_ty op)
      | Olt cmp_kind ->
        let (int_ty, sign) = cmp_kind_to_wasm cmp_kind in
        Lt (int_ty, sign)
      | Ole cmp_kind ->
        let (int_ty, sign) = cmp_kind_to_wasm cmp_kind in
        Le (int_ty, sign)
      | Ogt cmp_kind ->
        let (int_ty, sign) = cmp_kind_to_wasm cmp_kind in
        Gt (int_ty, sign)
      | Oge cmp_kind ->
        let (int_ty, sign) = cmp_kind_to_wasm cmp_kind in
        Ge (int_ty, sign)
      | Ovadd (velem, U128) -> Add (velem_to_op_ty velem)
      | Ovsub (velem, U128) -> Sub (velem_to_op_ty velem)
      | Ovmul (VE8, U128) -> gexpr_to_error (Papp2 (op, e1, e2))
      | Ovmul (velem, U128) -> Mul (velem_to_op_ty velem)
      | Obeq
      | Oand
      | Oor
      | Olsr _
      | Olsl _
      | Oasr _
      | Ovadd _
      | Ovsub _
      | Ovmul _
      | Ovlsr _
      | Ovlsl _
      | Ovasr _
      | Oror _
      | Orol _
      | Owi2 _ -> gexpr_to_error (Papp2 (op, e1, e2))
    in
    let i1 = gexpr_to_instr e1 in
    let i2 = gexpr_to_instr e2 in
    Binop (binop, i1, i2)

let gexprs_to_instrs ~(funname : funname) ~(i_loc : Location.i_loc) (es : 'len gexprs) : instrs =
  List.map (gexpr_to_instr ~funname ~i_loc) es

(* -------------------------------------------------------------------- *)

let fresh_block_name =
  let cpt = ref ~-1 in
  fun () ->
    incr cpt;
    Format.sprintf "$block_%d" !cpt

let fresh_loop_name =
  let cpt = ref ~-1 in
  fun () ->
    incr cpt;
    Format.sprintf "$loop_%d" !cpt

let rec ginstr_to_instrs ~(funname : funname) ({ i_desc ; i_loc ; _ } as instr : ('len, 'info, 'asm) ginstr) : instrs =
  let loc = Lmore i_loc in

  let ginstr_to_error = ginstr_to_error ~funname ~loc in

  let gexpr_to_instr = gexpr_to_instr ~funname ~i_loc in
  let gexprs_to_instrs = gexprs_to_instrs ~funname ~i_loc in
  let ginstrs_to_instrs = ginstrs_to_instrs ~funname in
  let set_instr = set_instr ~funname ~i_loc ~instr in
  let set_value = set_value ~funname ~i_loc ~instr in
  let set_pushed_values = set_pushed_values ~funname ~i_loc ~instr in
  let get_mulu = get_mulu ~funname ~i_loc ~instr in

  match i_desc with
  | Cassgn (glval, _tag, _gtype, gexpr) -> set_value gexpr glval
  | Cif (cond, then_, else_) ->
    let cond = gexpr_to_instr cond in
    let then_ = ginstrs_to_instrs then_ in
    let else_ = ginstrs_to_instrs else_ in
    [ if_ cond then_ else_ ]
  | Cwhile (_align, do_, cond, _info, while_) ->
    let block_name = fresh_block_name () in
    let loop_name = fresh_loop_name () in

    let do_ = ginstrs_to_instrs do_ in
    let while_ = ginstrs_to_instrs while_ in

    let cond = gexpr_to_instr cond in

    [ Block (Some block_name, [ Loop (Some loop_name,
      do_ @ [ if_ cond (while_ @ [ Br loop_name ]) [ Br block_name ] ]
    ) ] ) ]
  | Ccall (glvals, funname, args) ->
    let args = gexprs_to_instrs args in
    let call = Call (funname, args) in
    let sets = glvals |> List.rev |> set_pushed_values in
    call :: sets
  | Copn (_glvals, _tag, Opseudo_op Onop, _es) -> [ Nop ]
  | Copn ([], _tag, Opseudo_op (Odeclassify _aty), [ _ ]) -> [ Nop ]
  | Copn ([], _tag, Opseudo_op (Odeclassify_mem _pos), [ _ ]) -> [ Nop ]
  | Copn ([ x; y ], _tag, Opseudo_op (Omulu wsize), [ e1; e2 ]) -> get_mulu wsize x y e1 e2
  | Copn (([_; _] as glvals), _tag, Opseudo_op (Oswap _), ([_; _] as es)) ->
    let instrs = gexprs_to_instrs es in
    let sets = set_pushed_values glvals in
    instrs @ sets
  | Copn ([ x ], _tag, Oasm (Arch_extra.BaseOp (None, Wasm_instr_decl.VSHL velem)), [ e1; e2 ]) ->
    let op = Shl (velem_to_op_ty velem) in
    let i1 = gexpr_to_instr e1 in
    let i2 = gexpr_to_instr e2 in
    set_instr x (Binop (op, i1, i2))
  | Copn ([ x ], _tag, Oasm (Arch_extra.BaseOp (None, Wasm_instr_decl.VSHR (sign, velem))), [ e1; e2 ]) ->
    let op = Shr (velem_to_op_ty velem, sign) in
    let i1 = gexpr_to_instr e1 in
    let i2 = gexpr_to_instr e2 in
    set_instr x (Binop (op, i1, i2))
  | Copn ([ x ], _tag, Oasm (Arch_extra.BaseOp (None, Wasm_instr_decl.SWIZZLE)), [ e1; e2 ]) ->
    let i1 = gexpr_to_instr e1 in
    let i2 = gexpr_to_instr e2 in
    set_instr x (Binop (Swizzle, i1, i2))
  | Csyscall (([ _ ] as glvals), RandomBytes _, ([ _; _ ] as args)) ->
    let funname = randombytes_funname in
    let args = gexprs_to_instrs args in
    let call = Call (funname, args) in
    let sets = glvals |> List.rev |> set_pushed_values in
    call :: sets
  | Copn _
  | Csyscall _
  | Cassert _
  | Cfor _ -> ginstr_to_error instr

and ginstrs_to_instrs ~(funname : funname) (instrs : ('len, 'info, 'asm) ginstr list) : instrs =
  instrs |> List.map (ginstr_to_instrs ~funname) |> List.flatten

and set_instr ~(funname : funname) ~(i_loc : Location.i_loc) ~(instr : ('len, 'info, 'asm) ginstr) (glval : 'len glval) (winstr : instr) : instrs =
  let loc = Lmore i_loc in

  let ginstr_to_error = ginstr_to_error ~funname ~loc in

  let wsize_to_ty = wsize_to_ty ~funname ~loc in
  let igvar_to_var = igvar_to_var ~funname ~loc in

  let gexpr_to_instr = gexpr_to_instr ~funname ~i_loc in

  match glval with
  | Lnone _ -> [ winstr ; Drop ]
  | Lvar igvar ->
    let scope = igvar_to_scope igvar in
    let var = igvar_to_var igvar in
    [ set_ scope var winstr ]
  | Lmem (_align, wsize, _info, addr) ->
    let ty = wsize_to_ty wsize in
    let addr = gexpr_to_instr addr in
    [ store_ ty addr winstr ]
  | _ -> ginstr_to_error instr

and set_value ~(funname : funname) ~(i_loc : Location.i_loc) ~(instr : ('len, 'info, 'asm) ginstr) (gexpr : 'len gexpr) (glval : 'len glval) : instrs =
  let loc = Lmore i_loc in

  let wsize_to_size = wsize_to_size ~funname ~loc in
  let wsize_to_ty = wsize_to_ty ~funname ~loc in

  let gexpr_to_instr = gexpr_to_instr ~funname ~i_loc in
  let set_instr = set_instr ~funname ~i_loc ~instr in

  match glval, gexpr with
  (* Special cases *)
  | Lmem (_align, ((U8 | U16) as wsize), _info, addr), Papp1 (Oword_of_int wsize', Pconst num) when wsize = wsize' ->
    let store_ty = wsize_to_ty pointer_data in (* FIXME : which wsize choose ? *)
    let store_size = wsize_to_size wsize in
    let addr = gexpr_to_instr addr in
    let instr = const_num_ store_ty num in
    [ store_size_ store_ty store_size addr instr ]
  | Lmem (_align, ((U8 | U16) as desired), _info, addr), Papp1 (Ozeroext (desired', base), gexpr) when desired = desired' ->
    let store_ty = wsize_to_ty base in
    let store_size = wsize_to_size desired in
    let addr = gexpr_to_instr addr in
    let instr = gexpr_to_instr gexpr in
    [ store_size_ store_ty store_size addr instr ]
  (* Commom cases *)
  | _ -> set_instr glval (gexpr_to_instr gexpr)

and set_pushed_value ~(funname : funname) ~(i_loc : Location.i_loc) ~(instr : ('len, 'info, 'asm) ginstr) (glval : 'len glval) : instr =
  let loc = Lmore i_loc in

  let ginstr_to_error = ginstr_to_error ~funname ~loc in

  let wsize_to_ty = wsize_to_ty ~funname ~loc in
  let igvar_to_var = igvar_to_var ~funname ~loc in

  let gexpr_to_instr = gexpr_to_instr ~funname ~i_loc in

  match glval with
  | Lnone _ -> Drop
  | Lvar igvar ->
    let scope = igvar_to_scope igvar in
    let var = igvar_to_var igvar in
    set_stack_ scope var
  | Lmem (_aligned, wsize, _info, addr) ->
    let ty = wsize_to_ty wsize in
    let addr = gexpr_to_instr addr in
    store_stack_ ty addr
  | _ -> ginstr_to_error instr

and set_pushed_values ~(funname : funname) ~(i_loc : Location.i_loc) ~(instr : ('len, 'info, 'asm) ginstr) (glvals : 'len glvals) : instrs =
  List.map (set_pushed_value ~funname ~i_loc ~instr) glvals

and get_mulu ~(funname) ~(i_loc : Location.i_loc) ~(instr : ('len, 'info, 'asm) ginstr)
              (wsize : Wsize.wsize) (x : 'len glval) (y : 'len glval) (e1 : 'len gexpr) (e2 : 'len gexpr) : instrs =
  let loc = Lmore i_loc in

  let wsize_to_ty = wsize_to_ty ~funname ~loc in

  let gexpr_to_instr = gexpr_to_instr ~funname ~i_loc in
  let set_pushed_values = set_pushed_values ~funname ~i_loc ~instr in

  let e1 = gexpr_to_instr e1 in
  let e2 = gexpr_to_instr e2 in

  let ty = wsize_to_ty wsize in

  let shift_val, mask_val =
    match wsize with
    | U32 -> (16 |> Z.of_int |> z_to_num), (0xFFFF |> Z.of_int |> z_to_num)
    | U64 -> (32 |> Z.of_int |> z_to_num), (0xFFFFFFFF |> Z.of_int |> z_to_num)
    | _ -> assert false
  in
  let shift = const_num_ ty shift_val in
  let mask = const_num_ ty mask_val in

  let h1 = Binop (Shr (ty, Unsigned), e1, shift) in
  let h2 = Binop (Shr (ty, Unsigned), e2, shift) in
  let l1 = Binop (And ty, e1, mask) in
  let l2 = Binop (And ty, e2, mask) in

  let ll = Binop (Mul ty, l1, l2) in
  let lh = Binop (Mul ty, l1, h2) in
  let hl = Binop (Mul ty, h1, l2) in
  let hh = Binop (Mul ty, h1, h2) in

  let t1 = Binop (Add ty, hl, Binop (Shr (ty, Unsigned), ll, shift)) in
  let c1 = Binop (Shr (ty, Unsigned), t1, shift) in

  let t2 = Binop (Add ty, Binop (And ty, t1, mask), lh) in
  let c2 = Binop (Shr (ty, Unsigned), t2, shift) in

  let h = Binop (Add ty, hh, Binop (Add ty, c1, c2)) in
  let l = Binop (Mul ty, e1, e2) in

  let instrs = [ l; h ] in
  let sets = set_pushed_values [ x; y ] in

  instrs @ sets

(* -------------------------------------------------------------------- *)

let init_rip ?funname ?loc (locals : 'len gvar list) ~(rip_addr : Z.t) ~(rip : 'len gvar) : instr =
  let gty_to_int_ty = gty_to_int_ty ?funname ?loc in
  let gvar_to_var = gvar_to_var ?funname ?loc in

  let find_rip = List.exists (fun var -> GV.compare var rip = 0) locals in
  if not find_rip then Nop
  else begin
    let scope = gvar_to_scope rip in
    let var = gvar_to_var rip in
    let ty = rip |> gvar_type |> gty_to_int_ty in
    let num = z_to_num rip_addr in
    set_ scope var (const_num_ ty num)
  end

let init_rsp ?funname ?loc (locals : 'len gvar list) ~(rsp_addr : Z.t) ~(rsp : 'len gvar) : instr =
  let gty_to_int_ty = gty_to_int_ty ?funname ?loc in
  let gvar_to_var = gvar_to_var ?funname ?loc in

  let find_rsp = List.exists (fun var -> GV.compare var rsp = 0) locals in
  if not find_rsp then Nop
  else begin
    let scope = gvar_to_scope rsp in
    let var = gvar_to_var rsp in
    let ty = rsp |> gvar_type |> gty_to_int_ty in
    let num = z_to_num rsp_addr in
    set_ scope var (const_num_ ty num)
  end

let get_func ~(rsp_addr : Z.t) ~(rip_addr : Z.t) ~(rsp : 'len gvar) ~(rip : 'len gvar) ((_extra, func) : ('info, 'asm) sfundef) : func * funname option =
  let loc = Lone func.f_loc in
  let funname = func.f_name in
  let locals = func |> Prog.locals |> Sv.to_list in

  let gty_to_ty = gty_to_ty ~funname ~loc in
  let gvar_to_var = gvar_to_var ~funname ~loc in
  let igvar_to_var = igvar_to_var ~funname ~loc in

  let ginstrs_to_instrs = ginstrs_to_instrs ~funname in

  let init_rip = init_rip ~funname ~loc in
  let init_rsp = init_rsp ~funname ~loc in

  let func_name = funname in
  let func_params = List.map gvar_to_var func.f_args in
  let func_result = List.map gty_to_ty func.f_tyout in
  let func_locals = List.map gvar_to_var locals in

  let func_instrs =
    let init_rip = init_rip locals ~rip_addr ~rip in
    let init_rsp = init_rsp locals ~rsp_addr ~rsp in

    let gets = List.map (fun igvar -> Get (igvar_to_scope igvar, igvar_to_var igvar)) func.f_ret in
    let return = Return gets in

    (init_rip :: init_rsp :: ginstrs_to_instrs func.f_body) @ [ return ]
  in

  let def = { func_name ; func_params ; func_result ; func_locals ; func_instrs } in
  let export = if FInfo.is_export func.f_cc then Some func_name else None in
  (def, export)

let get_funcs ~(rsp_addr : Z.t) ~(rsp : 'len gvar) ~(rip_addr : Z.t) ~(rip : 'len gvar) (p_funcs : ('info, 'asm) sfundef list) : func list * funname list =
  let _rsp_addr, defs, exports =
    List.fold_left (
      fun (rsp_addr, defs, exports) ((extra, _func) as p_funcs) ->
        let (def, export) = get_func ~rsp_addr ~rsp ~rip_addr ~rip p_funcs in

        let rsp_addr = rsp_addr +@ cz_to_z extra.sf_stk_sz in
        let defs = def :: defs in
        let exports = if Option.is_some export then Option.get export :: exports else exports in

        (rsp_addr, defs, exports)
    ) (rsp_addr, [], []) p_funcs
  in

  let defs = List.rev defs in
  let exports = List.rev exports in
  (defs, exports)

(* -------------------------------------------------------------------- *)

let get_memory ~(mem_env : name) ~(mem_name : name) ~(mem_min : num) : mem list =
  [ { mem_env ; mem_name ; mem_min ; mem_max = None } ]

(* -------------------------------------------------------------------- *)

let get_randombytes_import ~(import_env : name) : import =
  let s = Syscall.syscall_sig_s pointer_data dummy_randombytes in
  let import_name = randombytes_funname in
  let import_args = s.scs_tin |> List.map Conv.ty_of_cty |> List.map gty_to_ty in
  let import_result = s.scs_tout |> List.map Conv.ty_of_cty |> List.map gty_to_ty  in
  { import_env ; import_name ; import_args ; import_result }

let get_imports ~(import_env : name) (funcs : ('info, 'asm) sfundef list) : import list =
  match has_randombytes_fs funcs with
  | false -> []
  | true -> [ get_randombytes_import ~import_env ]

(* -------------------------------------------------------------------- *)

let get_data ~(rip_addr : num) (sp_globs : Word.word list) : data =
  let data_ofs = rip_addr in
  let data_bytes = List.map cz_to_num sp_globs in
  { data_ofs; data_bytes }

let get_datas ~(rip_addr : num) (sp_globs : Word.word list) : data list =
  let data = get_data ~rip_addr sp_globs in
  match data.data_bytes with
  | [] -> []
  | _ -> [ data ]

(* -------------------------------------------------------------------- *)

let get_rsp_addr ~(rip_addr : Z.t) (sp_globs : Word.word list) : Z.t =
  rip_addr +@ Z.of_int (List.length sp_globs)

(* -------------------------------------------------------------------- *)

let compile_prog ~(mod_name : name) ~(mem_env : name) ~(mem_name : name) ~(mem_min : num) ~(import_env : name) ~(rip_addr : num)
                  ((funcs : ('info, 'asm) sfundef list), ({ sp_rsp ; sp_rip ; sp_globs ; _ } : E.sprog_extra)) : Wasm_ast.wasm_module =
  let rsp = sp_rsp in
  let rip = sp_rip in
  let rsp_addr = get_rsp_addr ~rip_addr sp_globs in

  let mod_mems = get_memory ~mem_env ~mem_name ~mem_min in
  let mod_imports = get_imports ~import_env funcs in
  let mod_datas = get_datas ~rip_addr sp_globs in
  let mod_funcs, mod_exports = get_funcs ~rsp_addr ~rip_addr ~rsp ~rip funcs in
  let mod_init = None in
  let mod_start = None in

  { mod_name; mod_mems ; mod_imports ; mod_datas; mod_funcs ; mod_init ; mod_exports ; mod_start }

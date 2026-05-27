type funname = CoreIdent.funname
type name = CoreIdent.Name.t
type uid = CoreIdent.uid

type scope = Expr.v_scope

type sign = Wsize.signedness

type num = Z.t

(* -------------------------------------------------------------------- *)

type size =
  | U8
  | U16
  | U32
  | U64

(* -------------------------------------------------------------------- *)

type simd_ty =
  | I8x16
  | I16x8
  | I32x4
  | I64x2

type extra_ty =
  | I8
  | I16

type ref_ty = name

type ty =
  | I32
  | I64
  | V128
  | Simd of simd_ty
  | Extra of extra_ty
  | Ref of ref_ty

(* -------------------------------------------------------------------- *)

type mutability =
  | Mutable
  | Immutable

type field_name = name

type field = field_name * mutability * ty

type ref_kind =
  | Array of mutability * ty
  | Struct of field list

type decl = {
  decl_name : ref_ty;
  decl_kind : ref_kind;
}

(* -------------------------------------------------------------------- *)

type var = {
  var_name : name;
  var_uid : uid;
  var_ty : ty;
}

(* -------------------------------------------------------------------- *)

type mem = {
  mem_env : name;
  mem_name : name;
  mem_min : num;
  mem_max : num option;
}

(* -------------------------------------------------------------------- *)

type import = {
  import_env : name;
  import_name : funname;
  import_args : ty list;
  import_result : ty list;
}

(* -------------------------------------------------------------------- *)

type data = {
  data_ofs : num;
  data_bytes : num list;
}

(* -------------------------------------------------------------------- *)

type unop =
  | Extend of sign (* Only for i32 -> i64 *)
  | Wrap (* Only for i64 -> i32 *)
  | Not (* Only for v128 *)
  | Splat of ty
  | Extract_lane of ty * sign option * num

type binop =
  | Add of ty
  | Sub of ty
  | Mul of ty
  | Div of ty * sign
  | Rem of ty * sign
  | And of ty
  | Or of ty
  | Xor of ty
  | Shr of ty * sign
  | Shl of ty
  | Rotr of ty
  | Rotl of ty
  | Eq of ty
  | Ne of ty
  | Lt of ty * sign
  | Le of ty * sign
  | Gt of ty * sign
  | Ge of ty * sign
  | Swizzle (* Only for the i8x16 interpretation *)
  | Shuffle of num list (* Only for the i8x16 interpretation *)
  | Replace_lane of ty * num

type instr =
  | Nop
  | Drop
  | Unop of unop * instr
  | Binop of binop * instr * instr
  | Const of ty * ty option * num list
  | Get of access * scope * var
  | Set of access * scope * var * instr option
  | Load of ty * size option * sign option * instr
  | Store of ty * size option * instr * instr option
  | If of ty list * instr * instrs * instrs
  | Call of funname * instrs
  | Block of name option * instrs
  | Loop of name option * instrs
  | Br of name
  | Return of instrs

and instrs = instr list

and access =
  | VarAccess
  | ArrayAccess of ref_ty * instr
  | StructAccess of ref_ty * field_name

(* -------------------------------------------------------------------- *)

type func = {
  func_name : funname;
  func_params : var list;
  func_result : ty list;
  func_locals : var list;
  func_instrs : instrs;
}

(* -------------------------------------------------------------------- *)

type wasm_module = {
  mod_name : name;
  mod_mems : mem list;
  mod_imports : import list;
  mod_datas : data list;
  mod_decls : decl list;
  mod_funcs : func list;
  mod_init : func option;
  mod_exports : funname list;
  mod_start : funname option;
}

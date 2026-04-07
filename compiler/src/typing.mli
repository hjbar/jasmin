open Prog

exception TyError of L.i_loc * string

val check_length : L.i_loc -> int -> unit
val ty_lval : Wsize.wsize -> L.i_loc -> lval -> ty
val type_of_op1 : Operators.sop1 -> ty * ty
val type_of_op2 : Operators.sop2 -> (ty * ty) * ty
val type_of_opN : Operators.opN -> ty list * ty
val ty_expr : Wsize.wsize -> L.i_loc -> expr -> ty
val error : Prog.L.i_loc -> ('a, Format.formatter, unit, 'b) format4 -> 'a

val check_prog :
  Wsize.wsize -> Wsize.wsize -> 'asm Sopn.asmOp -> ('info, 'asm) prog -> unit

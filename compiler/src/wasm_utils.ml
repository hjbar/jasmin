open Prog

(* -------------------------------------------------------------------- *)

let rec all_equal : 'a list -> bool = function
  | []
  | [ _ ] -> true
  | x :: y :: l -> x = y && all_equal (y :: l)

(* -------------------------------------------------------------------- *)

module Core = CoreArchFactory.Core_arch_WASM
module Arch = Arch_full.Arch_from_Core_arch_wasm (Core)
let pointer_data = Arch.pointer_data

(* -------------------------------------------------------------------- *)

let rec exists_i f { i_desc; _ } =
  f i_desc ||
  match i_desc with
  | Csyscall (_, RandomBytes _, _)
  | Cassgn _
  | Copn _
  | Ccall _
  | Cassert _ -> false
  | Cif (_, c1, c2) | Cwhile(_, c1, _, _, c2) -> exists_c f c1 || exists_c f c2
  | Cfor (_, _, c) -> exists_c f c

and exists_c f c = List.exists (exists_i f) c

let exists_f f (_, func) = exists_c f func.f_body

let exists_fs f funcs = List.exists (exists_f f) funcs

(* -------------------------------------------------------------------- *)

let has_randombytes_fs fs = exists_fs (function Csyscall (_, RandomBytes _, _) -> true | _ -> false) fs

(* -------------------------------------------------------------------- *)

let dummy_randombytes : (Wsize.wsize * BinNums.positive) Syscall_t.syscall_t = Syscall_t.RandomBytes (U8, Conv.pos_of_int 1)

let randombytes_funname : funname = CoreIdent.F.mk (Asm_utils.pp_syscall dummy_randombytes)

(* -------------------------------------------------------------------- *)

let is_arr_w (wsize : Wsize.wsize) : 'len gty -> bool = function
  | Arr (wsize', _len) -> wsize = wsize'
  | _ -> false

let has_ref_gv (w : Wsize.wsize) (gv : 'len gvar) : bool =
  is_arr_w w (gv.v_ty) && Annotations.has_symbol "ref" gv.v_annot

let has_ref_igv (w : Wsize.wsize) (igv : 'len gvar_i) : bool =
  has_ref_gv w igv.pl_desc

let has_ref_f (w : Wsize.wsize) ((_, f) : ('info, 'asm) sfundef) : bool =
  List.exists (has_ref_gv w) (f |> Prog.locals |> Sv.to_list) ||
  List.exists (has_ref_gv w) f.f_args ||
  List.exists (has_ref_igv w) f.f_ret

let has_ref_fs (w : Wsize.wsize) (fs : ('info, 'asm) sfundef list) : bool =
  List.exists (has_ref_f w) fs

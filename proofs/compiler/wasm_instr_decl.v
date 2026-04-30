(* special WASM instruction set *)

From elpi.apps Require Import derive.std.
From mathcomp Require Import ssreflect ssrfun ssrbool seq eqtype ssralg.
From mathcomp Require Import word_ssrZ.

Require Import
  sem_type
  shift_kind
  strings
  utils
  word.
Require xseq.
Require Import
  sopn
  arch_decl
  arch_utils.
Require Import wasm_decl.


Module E.
  Definition no_semantics : error := ErrType.
End E.

(* -------------------------------------------------------------------- *)
(* Helpers. *)

Definition signs :=
  [:: Signed; Unsigned].

Definition velems :=
  [:: VE8 ; VE16 ; VE32 ; VE64 ].

Definition wasm_lane_mask (velem : velem) : Z :=
  wsize_bits (wsize_of_velem velem) - 1.

Definition wasm_velem_conv_wsize (velem : velem) : wsize :=
  match velem with
  | VE64 => U64
  | VE32 | VE16 | VE8 => U32
  end.

Definition wasm_lane_min_index (_ : velem) : Z :=
  0.

Definition wasm_lane_max_index (velem : velem) : Z :=
  wsize_bits (wsize_of_velem velem) - 1.

Definition wasm_lane_index_out_of_bounds (velem : velem) (i : Z) : bool :=
  (i <? wasm_lane_min_index velem)%Z || (wasm_lane_max_index velem <? i)%Z.

Definition ak_reg_imm8_reg : i_args_kinds :=
    [:: [:: [:: CAreg ]; [:: CAimm_sz U8 ]; [:: CAreg ] ] ].

Definition ak_reg_reg_reg_imm128 : i_args_kinds :=
  [:: [:: [:: CAreg ]; [:: CAimm_sz U8 ]; [:: CAreg ] ; [:: CAimm_sz U128 ] ] ].

Definition ak_reg_imm8_reg_reg : i_args_kinds :=
  [:: [:: [:: CAreg ]; [:: CAimm_sz U8 ]; [:: CAreg ] ; [:: CAreg ] ] ].

Definition wasm_vec_binop_instr semi jazz_name asm_name : instr_desc_t :=
  let tin := [:: lword U128; lword U128 ] in
  let tout := [:: lword U128] in
  {|
      id_valid := true;
      id_msb_flag := MSB_MERGE;
      id_tin := tin;
      id_in := [:: Ea 1; Ea 2 ];
      id_tout := tout;
      id_out := [:: Ea 0 ];
      id_semi := sem_lprod_ok tin semi;
      id_nargs := 3;
      id_args_kinds := ak_reg_reg_reg;
      id_eq_size := refl_equal;
      id_check_dest := refl_equal;
      id_str_jas := jazz_name; (* how to print it in Jasmin *)
      id_safe := [::];
      id_pp_asm := asm_name; (* how to print it in asm *)
      id_safe_wf := refl_equal;
      id_semi_errty := fun _ => sem_lprod_ok_error tin semi;
      id_semi_safe := fun _ => sem_lprod_ok_safe tin semi;
  |}.

Definition wasm_vec_shift_instr semi jazz_name asm_name : instr_desc_t :=
  let tin := [:: lword U128; lword U32 ] in
  let tout := [:: lword U128] in
  {|
      id_valid := true;
      id_msb_flag := MSB_MERGE;
      id_tin := tin;
      id_in := [:: Ea 1; Ea 2 ];
      id_tout := tout;
      id_out := [:: Ea 0 ];
      id_semi := sem_lprod_ok tin semi;
      id_nargs := 3;
      id_args_kinds := ak_reg_reg_reg;
      id_eq_size := refl_equal;
      id_check_dest := refl_equal;
      id_str_jas := jazz_name; (* how to print it in Jasmin *)
      id_safe := [::];
      id_pp_asm := asm_name; (* how to print it in asm *)
      id_safe_wf := refl_equal;
      id_semi_errty := fun _ => sem_lprod_ok_error tin semi;
      id_semi_safe := fun _ => sem_lprod_ok_safe tin semi;
  |}.


(* -------------------------------------------------------------------- *)
(* Printing. *)

Definition string_of_signed_ve_sz (ve:velem) (sz:wsize) : string :=
  match ve, sz with
  | VE8, U16 => "2s8"
  | VE8, U32 => "4s8"
  | VE16, U32 => "2s16"
  | VE8, U64 => "8s8"
  | VE16, U64 => "4s16"
  | VE32, U64 => "2s32"
  | VE64, U64 => "1s64"
  | VE8 , U128 => "16s8"
  | VE16, U128 => "8s16"
  | VE32, U128 => "4s32"
  | VE64, U128 => "2s64"
  | VE8 , U256 => "32s8"
  | VE16, U256 => "16s16"
  | VE32, U256 => "8s32"
  | VE64, U256 => "4s64"
  | _,    _    => "ERROR: please repport"
  end.

Definition pp_sign_ve_sz (s: string) (sign : signedness) (ve: velem) (sz: wsize) (_: unit) : string :=
  s ++
  "_" ++
  (match sign with Signed => "s" | Unsigned => "u" end)%string ++
  (match sign with Signed => string_of_signed_ve_sz | Unsigned => string_of_ve_sz end) ve sz.

Definition pp_name name args :=
  {|
    pp_aop_name := name;
    pp_aop_ext := PP_name;
    pp_aop_args := map (fun a => (reg_size, a)) args;
  |}.

Definition wasm_vec128_velem_pp_asm (op : string) (sign : option signedness) (velem : velem) : asm_args -> pp_asm_op :=
  pp_name (
    "i"
    ++
    match velem with
    | VE8 => "8x16"
    | VE16 => "16x8"
    | VE32 => "32x4"
    | VE64 => "64x2"
    end
    ++
    "."
    ++
    op
    ++
    match sign with
    | None => ""
    | Some Signed => "_s"
    | Some Unsigned => "_u"
    end
  ).

Definition primV {A : Type} (ws : wsize) (f : velem -> A) : prim_constructor A :=
  PrimX86
    (map (fun v => PVv v ws) velems)
    (fun v => if v is PVv velem ws then Some (f velem) else None).

Definition primV128 {A : Type} (f : velem -> A) : prim_constructor A :=
  primV U128 f.

Definition primSV {A : Type} (ws : wsize) (f : (signedness * velem) -> A) : prim_constructor A :=
  PrimX86
    (List.flat_map (fun s => map (fun ve => PVsv s ve ws) velems) signs)
    (fun v => if v is PVsv sign velem ws then Some (f (sign, velem)) else None).

Definition primSV128 {A : Type} (f : (signedness * velem) -> A) : prim_constructor A :=
  primSV U128 f.

(* -------------------------------------------------------------------- *)
(* WASM 32I Base Integer instructions (operators). *)

#[only(eqbOK)] derive
Variant wasm_op : Type :=
| SPLAT of velem (* Vectorized splat instruction *)
| EXTRACT_LANE of signedness * velem (* Vectorized extract lane instruction *)
| REPLACE_LANE of velem (* Vectorized replace lane instruction *)
| SWIZZLE (* Swizzle i8x16 interpretation *)
| SHUFFLE (* Shuffle i8x16 interpretation *)
| VSHL of velem (* Vectorized Shift Left Logical *)
| VSHR of signedness * velem (* Vectorized Shift Right Signed/Unsigned *)
.

#[ export ]
Instance eqTC_wasm_op : eqTypeC wasm_op :=
  { ceqP := wasm_op_eqb_OK }.

Canonical wasm_op_eqType := @ceqT_eqType _ eqTC_wasm_op.

(* -------------------------------------------------------------------- *)
(* Instruction semantics and description. *)

Definition wasm_splat_semi (velem : velem) (c : word (wasm_velem_conv_wsize velem)) : word U128 :=
  wpbroadcast U128 c.

Definition wasm_SPLAT_instr (velem : velem) : instr_desc_t :=
  let semi := @wasm_splat_semi velem in
  let jazz_name := pp_ve_sz "SPLAT" velem U128 in
  let asm_name := wasm_vec128_velem_pp_asm "splat" None velem in
  let tin := [:: lword (wasm_velem_conv_wsize velem) ] in
  let tout := [:: lword U128 ] in
  {|
      id_valid := true;
      id_msb_flag := MSB_MERGE;
      id_tin := tin;
      id_in := [:: Ea 1 ];
      id_tout := tout;
      id_out := [:: Ea 0 ];
      id_semi := sem_lprod_ok tin semi;
      id_nargs := 2;
      id_args_kinds := ak_reg_reg;
      id_eq_size := refl_equal;
      id_check_dest := refl_equal;
      id_str_jas := jazz_name; (* how to print it in Jasmin *)
      id_safe := [::];
      id_pp_asm := asm_name; (* how to print it in asm *)
      id_safe_wf := refl_equal;
      id_semi_errty := fun _ => sem_lprod_ok_error tin semi;
      id_semi_safe := fun _ => sem_lprod_ok_safe tin semi;
  |}.

Definition prim_SPLAT : string * prim_constructor wasm_op :=
  ("SPLAT"%string, primV128 SPLAT).


Definition wasm_extract_lane_semi (sign : signedness) (velem : velem) (i : word U8) (v : word U128) : exec (word (wasm_velem_conv_wsize velem)) :=
  let i := wunsigned i in
  if wasm_lane_index_out_of_bounds velem i then Error E.no_semantics
  else
    let val := nth (0%w: word (wsize_of_velem velem)) (split_vec velem v) (Z.to_nat i) in
    let val := match velem, sign return word (wsize_of_velem velem) -> word (wasm_velem_conv_wsize velem) with
    | (VE32 | VE64), _ => fun val => val
    | (VE8 | VE16), Signed => fun val => wrepr U32 (wsigned val)
    | (VE8 | VE16), Unsigned => fun val => wrepr U32 (wunsigned val)
    end val in
    ok val.

Lemma wasm_extract_lane_semi_errty (sign : signedness) (velem : velem) :
  sem_lforall (fun r : result error (sem_ltuple [:: lword (wasm_velem_conv_wsize velem) ]) => r <> Error ErrType)
    [:: lword8; lword128] (wasm_extract_lane_semi sign velem).
Proof.
Admitted.

Lemma wasm_extract_lane_semi_safe (sign : signedness) (velem : velem) :
  interp_safe_cond_lty [:: lword8; lword128] [::] (wasm_extract_lane_semi sign velem).
Proof.
Admitted.

Definition wasm_EXTRACT_LANE_instr (sign : signedness) (velem : velem) : instr_desc_t :=
  let semi := @wasm_extract_lane_semi sign velem in
  let semi_errty := @wasm_extract_lane_semi_errty sign velem in
  let semi_safe := @wasm_extract_lane_semi_safe sign velem in
  let jazz_name := pp_sign_ve_sz "EXTRACT_LANE" sign velem U128 in
  let asm_name := wasm_vec128_velem_pp_asm "extract_lane" (Some sign) velem in
  let tin := [:: lword U8; lword U128 ] in
  let tout := [:: lword (wasm_velem_conv_wsize velem) ] in
  {|
      id_valid := true;
      id_msb_flag := MSB_MERGE;
      id_tin := tin;
      id_in := [:: Ea 1; Ea 2 ];
      id_tout := tout;
      id_out := [:: Ea 0 ];
      id_semi := semi;
      id_nargs := 3;
      id_args_kinds := ak_reg_imm8_reg;
      id_eq_size := refl_equal;
      id_check_dest := refl_equal;
      id_str_jas := jazz_name; (* how to print it in Jasmin *)
      id_safe := [::];
      id_pp_asm := asm_name; (* how to print it in asm *)
      id_safe_wf := refl_equal;
      id_semi_errty := fun _ => semi_errty;
      id_semi_safe := fun _ => semi_safe;
  |}.

Definition prim_EXTRACT_LANE : string * prim_constructor wasm_op :=
  ("EXTRACT_LANE"%string, primSV128 EXTRACT_LANE).


Definition wasm_replace_lane_semi (velem : velem) (i : word U8) (v : word U128) (c : word (wasm_velem_conv_wsize velem)) : exec (word U128) :=
  if wasm_lane_index_out_of_bounds velem (wunsigned i) then Error E.no_semantics
  else ok (wpinsr v c i).

Lemma wasm_replace_lane_semi_errty (velem : velem) :
  sem_lforall (fun r : result error (sem_ltuple [:: lword U128]) => r <> Error ErrType)
    [:: lword U8; lword U128; lword (wasm_velem_conv_wsize velem) ] (@wasm_replace_lane_semi velem).
Proof.
Admitted.

Lemma wasm_replace_lane_semi_safe (velem : velem) :
  interp_safe_cond_lty [:: lword U8; lword U128; lword (wasm_velem_conv_wsize velem) ]
    [::] (@wasm_replace_lane_semi velem).
Proof.
Admitted.

Definition wasm_REPLACE_LANE_instr (velem : velem) : instr_desc_t :=
  let semi := @wasm_replace_lane_semi velem in
  let semi_errty := @wasm_replace_lane_semi_errty velem in
  let semi_safe := @wasm_replace_lane_semi_safe velem in
  let jazz_name := pp_ve_sz "REPLACE_LANE" velem U128 in
  let asm_name := wasm_vec128_velem_pp_asm "replace_lane" None velem in
  let tin := [:: lword U8; lword U128; lword (wasm_velem_conv_wsize velem) ] in
  let tout := [:: lword U128] in
  {|
      id_valid := true;
      id_msb_flag := MSB_MERGE;
      id_tin := tin;
      id_in := [:: Ea 1; Ea 2; Ea 3 ];
      id_tout := tout;
      id_out := [:: Ea 0 ];
      id_semi := semi;
      id_nargs := 4;
      id_args_kinds := ak_reg_imm8_reg_reg;
      id_eq_size := refl_equal;
      id_check_dest := refl_equal;
      id_str_jas := jazz_name; (* how to print it in Jasmin *)
      id_safe := [::];
      id_pp_asm := asm_name; (* how to print it in asm *)
      id_safe_wf := refl_equal;
      id_semi_errty := fun _ => semi_errty;
      id_semi_safe := fun _ => semi_safe;
  |}.

Definition prim_REPLACE_LANE : string * prim_constructor wasm_op :=
  ("REPLACE_LANE"%string, primV128 REPLACE_LANE).


Definition wasm_swizzle_semi (v : word U128) (c : word U128) : word U128 :=
  lift2_vec U128 (@wpshufb U128) U128 v c.

Definition wasm_SWIZZLE_instr : instr_desc_t :=
  let jazz_name := pp_ve_sz "SWIZZLE" VE8 U128 in
  let pp_asm := wasm_vec128_velem_pp_asm "swizzle" None VE8 in
  wasm_vec_binop_instr wasm_swizzle_semi jazz_name pp_asm.

Definition prim_SWIZZLE : string * prim_constructor wasm_op :=
  ("SWIZZLE"%string, primM SWIZZLE).


Definition wasm_shuffle_semi (v1 v2 mask : word U128) : exec (word U128) :=
  let bytes := split_vec VE8 v1 ++ split_vec VE8 v2 in
  let indices := split_vec VE8 mask in
  if has (fun i => (31 <? wunsigned i)%Z) indices then Error E.no_semantics
  else
    let get_byte idx := nth (0%w: word U8) bytes (Z.to_nat (wunsigned idx)) in
    ok (make_vec U128 (map get_byte indices)).

Lemma wasm_shuffle_semi_errty :
  sem_lforall (fun r : result error (sem_ltuple [:: lword U128]) => r <> Error ErrType)
    [:: lword U128; lword U128; lword U128 ] wasm_shuffle_semi.
Proof.
Admitted.

Lemma wasm_shuffle_semi_safe :
  interp_safe_cond_lty [:: lword U128; lword U128; lword U128 ] [::] wasm_shuffle_semi.
Proof.
Admitted.

Definition wasm_SHUFFLE_instr : instr_desc_t :=
  let semi := wasm_shuffle_semi in
  let semi_errty := wasm_shuffle_semi_errty in
  let semi_safe := wasm_shuffle_semi_safe in
  let jazz_name := pp_ve_sz "SHUFFLE" VE8 U128 in
  let asm_name := wasm_vec128_velem_pp_asm "shuffle" None VE8 in
  let tin := [:: lword U128; lword U128; lword U128 ] in
  let tout := [:: lword U128] in
  {|
      id_valid := true;
      id_msb_flag := MSB_MERGE;
      id_tin := tin;
      id_in := [:: Ea 1; Ea 2; Ea 3 ];
      id_tout := tout;
      id_out := [:: Ea 0 ];
      id_semi := semi;
      id_nargs := 4;
      id_args_kinds := ak_reg_reg_reg_imm128;
      id_eq_size := refl_equal;
      id_check_dest := refl_equal;
      id_str_jas := jazz_name; (* how to print it in Jasmin *)
      id_safe := [::];
      id_pp_asm := asm_name; (* how to print it in asm *)
      id_safe_wf := refl_equal;
      id_semi_errty := fun _ => semi_errty;
      id_semi_safe := fun _ => semi_safe;
  |}.

Definition prim_SHUFFLE : string * prim_constructor wasm_op :=
  ("SHUFFLE"%string, primM SHUFFLE).


Definition wasm_vshl_semi (velem : velem) (v : word U128) (n : word U32) : word U128 :=
  let mask := wrepr U32 (wasm_lane_mask velem) in
  let n := wunsigned (wand n mask) in
  lift1_vec (wsize_of_velem velem) (fun lane => wshl lane n) U128 v.

Definition wasm_VSHL_instr (velem : velem) : instr_desc_t :=
  let semi := wasm_vshl_semi velem in
  let jazz_name := pp_ve_sz "VSHL" velem U128 in
  let pp_asm := wasm_vec128_velem_pp_asm "shl" None velem in
  wasm_vec_shift_instr semi jazz_name pp_asm.

Definition prim_VSHL : string * prim_constructor wasm_op :=
  ("VSHL"%string, primV128 VSHL).


Definition wasm_vshr_semi (sign : signedness) (velem : velem) (v : word U128) (n : word U32) : word U128 :=
  let mask := wrepr U32 (wasm_lane_mask velem) in
  let n := wunsigned (wand n mask) in
  lift1_vec (wsize_of_velem velem)
    (fun lane =>
      match sign with
      | Unsigned => wshr lane n
      | Signed   => wsar lane n
      end)
    U128 v.

Definition wasm_VSHR_instr (sign : signedness) (velem : velem) : instr_desc_t :=
  let semi := wasm_vshr_semi sign velem in
  let jazz_name := pp_sign_ve_sz "VSHR" sign velem U128 in
  let pp_asm := wasm_vec128_velem_pp_asm "shr" (Some sign) velem in
  wasm_vec_shift_instr semi jazz_name pp_asm.

Definition prim_VSHR : string * prim_constructor wasm_op :=
  ("VSHR"%string, primSV128 VSHR).


(* -------------------------------------------------------------------- *)
(* Description of instructions. *)

Definition wasm_instr_desc (mn : wasm_op) : instr_desc_t :=
  match mn with
  | SPLAT velem => wasm_SPLAT_instr velem
  | EXTRACT_LANE (sign, velem) => wasm_EXTRACT_LANE_instr sign velem
  | REPLACE_LANE velem => wasm_REPLACE_LANE_instr velem
  | SWIZZLE => wasm_SWIZZLE_instr
  | SHUFFLE => wasm_SHUFFLE_instr
  | VSHL velem => wasm_VSHL_instr velem
  | VSHR (sign, velem) => wasm_VSHR_instr sign velem
  end.

Definition wasm_prim_string : seq (string * prim_constructor wasm_op) := [::
  prim_SPLAT;
  prim_EXTRACT_LANE;
  prim_REPLACE_LANE;
  prim_SWIZZLE;
  prim_SHUFFLE;
  prim_VSHL;
  prim_VSHR
].

#[ export ]
Instance wasm_op_decl : asm_op_decl wasm_op :=
  {|
    instr_desc_op := wasm_instr_desc;
    prim_string := wasm_prim_string;
  |}.

Definition wasm_prog := @asm_prog _ _ _ _ _ _ _ wasm_op_decl.

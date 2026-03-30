open Utils
open Prog
open Glob_options

let preprocess pd msfsize asmOp p =
  let p =
    p |> Subst.remove_params |> Insert_copy_and_fix_length.doit pd
  in
  Typing.check_prog pd msfsize asmOp p;
  p

(* -------------------------------------------------------------------- *)

let parse_jasmin_path s =
  s |> String.split_on_char ':' |> List.map (String.split ~by:"=")

let get_jasminpath () =
  match Sys.getenv "JASMINPATH" with
  | exception Not_found -> []
  | path ->
  try parse_jasmin_path path with
  | Not_found ->
  warning Always Location.i_dummy "ill-formed value for the JASMINPATH environment variable";
  []

let parse_file arch_info ?(idirs=[]) fname =
  let idirs = idirs @ get_jasminpath () in
  let env = List.fold_left Pretyping.Env.add_from Pretyping.Env.empty idirs in
  Pretyping.tt_program arch_info env fname

(* -------------------------------------------------------------------- *)
let rec warn_extra_i pd msfsize asmOp i =
  match i.i_desc with
  | Cassgn (_, tag, _, _) | Copn (_, tag, _, _) -> (
      match tag with
      | AT_rename ->
          warning ExtraAssignment i.i_loc
            "@[<v>extra assignment introduced:@;<0 2>%a@]"
            (Printer.pp_instr ~debug:false pd msfsize asmOp)
            i
      | AT_inline ->
          hierror ~loc:(Lmore i.i_loc) ~kind:"compilation error" ~internal:true
            "@[<v>AT_inline flag remains in instruction:@;<0 2>@[%a@]@]"
            (Printer.pp_instr ~debug:false pd msfsize asmOp)
            i
      | _ -> ())
  | Cif (_, c1, c2) | Cwhile (_, c1, _, _, c2) ->
      List.iter (warn_extra_i pd msfsize asmOp) c1;
      List.iter (warn_extra_i pd msfsize asmOp) c2
  | Cfor _ ->
      hierror ~loc:(Lmore i.i_loc) ~kind:"compilation error" ~internal:true
        "for loop remains"
  | Ccall _ | Csyscall _ | Cassert _ -> ()

let warn_extra_fd pd msfsize asmOp (_, fd) = List.iter (warn_extra_i pd msfsize asmOp) fd.f_body

(* -------------------------------------------------------------------- *)

let do_spill_unspill asmop ?(debug = false) cp =
  let p = Conv.cuprog_of_prog cp in
  match Lower_spill.spill_uprog asmop Conv.fresh_var_ident p with
  | Utils0.Error msg -> Error (Conv.error_of_cerror (Printer.pp_err ~debug) msg)
  | Utils0.Ok p -> Ok (Conv.prog_of_cuprog p)

let catch_error cp =
  match cp with
  | Utils0.Ok cp -> cp
  | Utils0.Error e ->
    let e = Conv.error_of_cerror (Printer.pp_err ~debug:false) e in
    raise (HiError e)

let do_wint_int
   (type reg regx xreg rflag cond asm_op extra_op)
    (module Arch : Arch_full.Arch
      with type reg = reg
       and type regx = regx
       and type xreg = xreg
       and type rflag = rflag
       and type cond = cond
       and type asm_op = asm_op
       and type extra_op = extra_op) prog =
  let fdsi = snd prog in
  let get_info p =
    let p = Conv.prog_of_cuprog p in
    let fv = List.fold_left (fun fv fd -> Sv.union fv (vars_fc_contract fd)) Sv.empty (snd p) in
    let m =
      Sv.fold (fun x m ->
          match x.v_ty with
          | Bty (U _) ->
            begin match Annotations.has_wint x.v_annot with
            | None -> m
            | Some sg ->
              let annot = Annotations.remove_wint x.v_annot in
              let xi = V.mk x.v_name x.v_kind tint x.v_dloc annot in
              Mv.add x (sg, Conv.cvar_of_var xi) m
            end
          | _ -> m)
      fv Mv.empty in
    let info x =
      let x = Conv.var_of_cvar x in
      Mv.find_opt x m in
    Conv.csv_of_sv fv ,info
  in
  let cp = Conv.cuprog_of_prog prog in
  let cp = Wint_int.wi2i_prog Arch.asmOp Arch.pointer_data Arch.msf_size get_info cp in
  let cp = catch_error cp in
  let (gd, fdso) = Conv.prog_of_cuprog cp in
  (* Restore type of array in the functions signature *)
  let restore_ty tyi tyo =
    match tyi, tyo with
    | Arr(ws1, l1), Arr(ws2, l2) -> assert (arr_size ws1 l1 = arr_size ws2 l2); tyi
    | Bty (U _), Bty Int -> tyo
    | _, _ -> assert (tyi = tyo); tyo
  in
  let restore_sig fdi fdo =
    { fdo with
      f_tyin = List.map2 restore_ty fdi.f_tyin fdo.f_tyin;
      f_tyout = List.map2 restore_ty fdi.f_tyout fdo.f_tyout;
    } in
  let fds = List.map2 restore_sig fdsi fdso in
  (gd, fds)


(*--------------------------------------------------------------------- *)

let compile (type reg regx xreg rflag cond asm_op extra_op)
    (module Arch : Arch_full.Arch_wasm
      with type reg = reg
       and type regx = regx
       and type xreg = xreg
       and type rflag = rflag
       and type cond = cond
       and type asm_op = asm_op
       and type extra_op = extra_op) visit_prog_after_pass prog cprog =
  let module RA = Regalloc_wasm.Regalloc (Arch) in
  let module StackAlloc = StackAlloc_wasm.StackAlloc (Arch) in
  let fdef_of_cufdef fn cfd = Conv.fdef_of_cufdef (fn, cfd) in
  let cufdef_of_fdef fd = snd (Conv.cufdef_of_fdef fd) in

  let apply msg trans fn cfd =
    if !debug then Format.eprintf "START %s@." msg;
    let fd = fdef_of_cufdef fn cfd in
    if !debug then Format.eprintf "back to ocaml@.";
    let fd = trans fd in
    cufdef_of_fdef fd
  in

  (* Kind of duplicate of pp_sub_region... *)
  let pp_sr sr =
    let open Compiler_util in
    pp_vbox [
      pp_nobox [
        PPEstring "{ region = ";
        PPEstring (Format.asprintf "%a" (Pp_stack_alloc.pp_region ~debug:!debug) sr.Stack_alloc.sr_region);
        PPEstring ";"];
      pp_nobox [
        PPEstring "  zone = ";
        PPEstring (Format.asprintf "%a" (Pp_stack_alloc.pp_symbolic_zone ~debug:!debug) sr.Stack_alloc.sr_zone);
        PPEstring " }"]];
  in

  let memory_analysis up : Compiler_wasm.stack_alloc_oracles =
    StackAlloc.memory_analysis
      pp_sr
      (Printer.pp_err ~debug:!debug)
      ~debug:!debug up
  in

  let global_regalloc fds =
    if !debug then Format.eprintf "START regalloc@.";
    let fds = List.map Conv.fdef_of_csfdef fds in

    CheckAnnot.check_stack_size fds;


    let return_addresses =
      let ra = Hf.create 17 in
      List.iter (fun (extra, fd) ->
          let conv = Conv.var_of_cvar in
          let oconv = Option.map conv in
          let r =
          match extra.Expr.sf_return_address with
          | RAstack (None, _, _, _)
          | RAnone -> Regalloc_wasm.StackDirect
          | RAreg (r, tmp) -> ByReg (conv r, oconv tmp)
          | RAstack (Some call, return, _, tmp) -> StackByReg (conv call, oconv return, oconv tmp)
          in Hf.add ra fd.f_name r
          ) fds;
      ra
    in

    let subst, _killed, fds = RA.alloc_prog return_addresses fds in
    let subst_sf_return_address : Expr.stk_fun_extra -> Expr.stk_fun_extra =
      let subst x = x |> Conv.var_of_cvar |> subst |> Conv.cvar_of_var in
      let osubst = Option.map subst in
      fun fe ->
      { fe with
        Expr.sf_return_address =
          match fe.Expr.sf_return_address with
          | RAnone -> RAnone;
          | RAreg (ret, tmp) -> RAreg (subst ret, osubst tmp)
          | RAstack (c, r, n, t) -> RAstack (osubst c, osubst r, n, osubst t)
      }
    in
    let fds = List.map (fun (e, fd) -> subst_sf_return_address e, fd) fds in
    let fds = List.map Conv.csfdef_of_fdef fds in
    fds
  in

  let pp_cuprog s cp =
    Conv.prog_of_cuprog cp |> visit_prog_after_pass ~debug:true s
  in

  let pp_csprog fmt cp =
    let p = Conv.prog_of_csprog cp in
    Printer.pp_sprog ~debug:true Arch.pointer_data Arch.msf_size Arch.asmOp fmt p
  in

  let pp_linear fmt lp = PrintLinear.pp_prog Arch.pointer_data Arch.msf_size Arch.asmOp fmt lp in

  let extend_iinfo ii1 ii2 =
    let l1 =
      let ii1, _ = ii1 in
      let { L.base_loc = b1; L.stack_loc = l1 } = ii1 in
      b1 :: l1
    in
    let ii2, annot2 = ii2 in
    let ii2 =
      let { L.base_loc = b2; L.stack_loc = l2 } = ii2 in
      L.i_loc b2 (l2 @ l1)
    in
    ii2, annot2
  in

  let expand_fd fn cfd =
    let fd = Conv.fdef_of_cufdef (fn, cfd) in
    let vars, harrs = Array_expand.init_tbl fd in
    let cvar = Conv.cvar_of_var in
    let vars = List.map cvar (Sv.elements vars) in
    let arrs = ref [] in
    let doarr x (ws, xs) =
      arrs :=
        Array_expansion.
          {
            vi_v = cvar x;
            vi_s = ws;
            vi_n =
              List.map (fun x -> (cvar x).Var0.Var.vname) (Array.to_list xs);
          }
        :: !arrs
    in
    Hv.iter doarr harrs;

    let do_outannot x a =
      try
        let (_, va) = Hv.find harrs (L.unloc x) in
        List.init (Array.length va) (fun _ -> [])
      with Not_found -> [a] in
    let ret_annot = List.flatten (List.map2 do_outannot fd.f_ret fd.f_ret_info.ret_annot) in
    let finfo = fd.f_loc, fd.f_annot, fd.f_cc, { fd.f_ret_info with ret_annot } in
    { Array_expansion.vars; arrs = !arrs; finfo }
  in

  let refresh_instr_info fn f =
    (fn, f) |> Conv.fdef_of_cufdef |> refresh_i_loc_f |> Conv.cufdef_of_fdef |> snd
  in

  let warning ii msg =
    (if not !Glob_options.lea then
     let loc, _ = ii in
     warning UseLea loc "%a" Printer.pp_warning_msg msg);
    ii
  in

  let fresh_id _gd x =
    let x = Conv.var_of_cvar x in
    Prog.V.clone x
  in

  let split_live_ranges_fd fd = Ssa.split_live_ranges true fd in
  let renaming_fd fd = RA.renaming fd in
  let remove_phi_nodes_fd fd = Ssa.remove_phi_nodes fd in

  let removereturn sp =
    let fds, _data = Conv.prog_of_csprog sp in
    let tokeep = RemoveUnusedResults.analyse fds in
    tokeep
  in

  let remove_wint_annot fd =
    let vars = Prog.vars_fc fd in
    let subst =
      Sv.fold (fun x s ->
          if Annotations.has_wint x.v_annot = None then s
          else
            let annot = Annotations.remove_wint x.v_annot in
            let x' = V.mk x.v_name x.v_kind x.v_ty x.v_dloc annot in
            Mv.add x x' s)
        vars Mv.empty in
    Subst.vsubst_func subst fd
  in

  let warn_extra s p =
    if s = Compiler_wasm.DeadCode_RegAllocation then
      let fds, _ = Conv.prog_of_csprog p in
      List.iter (warn_extra_fd Arch.pointer_data Arch.msf_size Arch.asmOp) fds
  in

  let slh_info up =
    let p = Conv.prog_of_cuprog up in
    let ttbl = Sct_checker_forward.compile_infer_msf p in
    fun fn ->
      try Hf.find ttbl fn with Not_found -> assert false
  in

  let tbl_annot =
    let tbl = Hf.create 17 in
    let add (fn, cfd) =
      let fd = fdef_of_cufdef fn cfd in
      Hf.add tbl fn fd.f_annot
    in
    List.iter add cprog.Expr.p_funcs;
    tbl
  in

  let get_annot fn =
    try Hf.find tbl_annot fn
    with Not_found ->
           hierror
             ~loc:Lnone
             ~funname:fn.fn_name
             ~kind:"compiler error"
             ~internal:true
             "invalid annotation table."
  in

  let szs_of_fn fn =
    (get_annot fn).stack_zero_strategy
  in

  (* This implements an analysis returning the set of variables becoming dead
     after each instruction. It is based on the liveness analysis available
     in Liveness. *)
  let dead_vars_fd (f : _ func) =
    let hvars = Hashtbl.create 97 in
    let live = Liveness.live_fd false f in
    let rec analyze (i : _ ginstr) =
      begin match i.i_desc with
      | Cif (_, c1, c2) -> List.iter analyze c1; List.iter analyze c2
      | Cfor (_, _, c) -> List.iter analyze c
      | Cwhile (_, c, _, _, c') -> List.iter analyze c; List.iter analyze c'
      | _ -> ()
      end;
      let (in_set, out_set) = i.i_info in
      let s = Conv.csv_of_sv (Sv.diff in_set out_set) in
      if Hashtbl.mem hvars i.i_loc then begin
          (* If there is an entry already, the i_locs have duplicates:
             this should not happen, hence the warning, but we can safely continue by
             assuming that no variable dies here *)
          Utils.warning Always i.i_loc "Bug! Please report.";
          Hashtbl.replace hvars i.i_loc Var0.SvExtra.Sv.empty
      end else
        Hashtbl.add hvars i.i_loc s
    in
    List.iter analyze live.f_body;

    fun ii ->
      let loc, _ = ii in
      try Hashtbl.find hvars loc with
      | Not_found ->
          hierror ~loc:(Lmore loc) ~kind:"compilation error" ~internal:true
            "dead_vars_fd: location not found"
  in

  (* We expose a version of dead_vars_fd for _ufun_decl. *)
  let dead_vars_ufd (f : _ Expr._ufun_decl) =
    let f = Conv.fdef_of_cufdef f in
    dead_vars_fd f
  in

  (* We expose a version of dead_vars_fd for _sfun_decl. *)
  let dead_vars_sfd (f : _ Expr._sfun_decl) =
    let _, f = Conv.fdef_of_csfdef f in
    dead_vars_fd f
  in

  let cparams =
    {
      Compiler_wasm.extend_iinfo;
      Compiler_wasm.expand_fd;
      Compiler_wasm.split_live_ranges_fd =
        apply "split live ranges" split_live_ranges_fd;
      Compiler_wasm.renaming_fd = apply "alloc inline assgn" renaming_fd;
      Compiler_wasm.remove_phi_nodes_fd =
        apply "remove phi nodes" remove_phi_nodes_fd;
      Compiler_wasm.stack_register_symbol =
        Var0.Var.vname (Conv.cvar_of_var Arch.rsp_var);
      Compiler_wasm.global_static_data_symbol =
        Var0.Var.vname (Conv.cvar_of_var Arch.rip);
      Compiler_wasm.stackalloc = memory_analysis;
      Compiler_wasm.removereturn;
      Compiler_wasm.insert_renaming =
        if !Glob_options.introduce_export_renaming then
          fun (_, _, cc, _) -> FInfo.is_export cc
        else Fun.const false;
      Compiler_wasm.remove_wint_annot =
        apply "remove wint annot" remove_wint_annot;
      Compiler_wasm.regalloc = global_regalloc;
      Compiler_wasm.print_uprog =
        (fun s p ->
          pp_cuprog s p;
          p);
      Compiler_wasm.print_sprog =
        (fun s p ->
          warn_extra s p;
          eprint (Compile_utils.from_wasm_step s) pp_csprog p;
          p);
      Compiler_wasm.print_linear =
        (fun s p ->
          eprint (Compile_utils.from_wasm_step s) pp_linear p;
          p);
      Compiler_wasm.refresh_instr_info;
      Compiler_wasm.warning;
      Compiler_wasm.fresh_id;
      Compiler_wasm.fresh_var_ident = Conv.fresh_var_ident;
      Compiler_wasm.slh_info;
      Compiler_wasm.stack_zero_info = szs_of_fn;
      Compiler_wasm.dead_vars_ufd;
      Compiler_wasm.dead_vars_sfd;
      Compiler_wasm.pp_sr;
    }
  in

  let export_functions =
    let conv fd = fd.f_name in
    List.fold_right
      (fun fd acc ->
        match fd.f_cc with
        | Export -> conv fd :: acc
        | Internal | Subroutine -> acc)
      (snd prog) []
  in

  Compiler_wasm.compiler_front_end Arch.asm_e Arch.aparams cparams export_functions (Expr.to_uprog Arch.asmOp cprog)

(* -------------------------------------------------------------------- *)

let gvar_uid (gvar : int gvar) : uid =
  gvar.v_id

let gvar_name (gvar : int gvar) : string =
  Format.sprintf "%s.%s" (gvar.v_name) (string_of_uid (gvar_uid gvar))

let gvar_type (gvar : int gvar) : int gty =
  gvar.v_ty

let gvar_is_glob (gvar : int gvar) : bool =
  gvar.v_kind = Global

let gvar_is_local (gvar : int gvar) : bool =
  gvar |> gvar_is_glob |> not

let igvar_name (gvar_i : int gvar_i) : string =
  gvar_name gvar_i.pl_desc

let ggvar_name (ggvar : int ggvar) : string =
  igvar_name ggvar.gv

(* -------------------------------------------------------------------- *)

let int2doc = string_of_int

let z2doc z = z |> Z.to_int |> int2doc

let pos2doc pos = pos |> Conv.int_of_pos |> int2doc

let size2doc : Wsize.wsize -> string = function
  | U8   -> "U8"
  | U16  -> "U16"
  | U32  -> "U32"
  | U64  -> "U64"
  | U128 -> "U128"
  | U256 -> "U256"

let type2doc : int gty -> string = function
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

let gvar2doc (gvar : int gvar) : string =
  Format.sprintf "gvar(%s, %s, %s)" (gvar_name gvar) (string_of_uid (gvar_uid gvar)) (type2doc (gvar_type gvar))

let igvar2doc (igvar : int gvar_i) : string =
  gvar2doc igvar.pl_desc

let ggvar2doc (ggvar : int ggvar) : string =
  igvar2doc ggvar.gv

(* -------------------------------------------------------------------- *)

let unop2doc : Operators.sop1 -> string = function
  | Oword_of_int wsize -> Format.sprintf "Oword_of_int(%s)" (size2doc wsize)
  | Oint_of_word (sign, wsize) -> Format.sprintf "Oint_of_word(%s, %s)" (sign2doc sign) (size2doc wsize)
  | Osignext (ws1, ws2) -> Format.sprintf "Osignext(%s, %s)" (size2doc ws1) (size2doc ws2)
  | Ozeroext (ws1, ws2) -> Format.sprintf "Ozeroext(%s, %s)" (size2doc ws1) (size2doc ws2)
  | Onot -> "Onot"
  | Olnot wsize -> Format.sprintf "Olnot(%s)" (size2doc wsize)
  | Oneg op -> Format.sprintf "Oneg(%s)" (op_kind2doc op)
  | Owi1 (sign, _op) -> Format.sprintf "Owi1(%s, _)" (sign2doc sign)

let binop2doc : Operators.sop2 -> string = function
  | Obeq -> "Obeq"
  | Oand -> "Oand"
  | Oor -> "Oor"
  | Oadd op -> Format.sprintf "Oadd(%s)" (op_kind2doc op)
  | Omul op -> Format.sprintf "Omul(%s)" (op_kind2doc op)
  | Osub op -> Format.sprintf "Osub(%s)" (op_kind2doc op)
  | Odiv (sign, op) -> Format.sprintf "Odiv(%s, %s)" (sign2doc sign) (op_kind2doc op)
  | Omod (sign, op) -> Format.sprintf "Omod(%s, %s)" (sign2doc sign) (op_kind2doc op)
  | Oland wsize -> Format.sprintf "Oland(%s)" (size2doc wsize)
  | Olor wsize -> Format.sprintf "Olor(%s)" (size2doc wsize)
  | Olxor wsize -> Format.sprintf "Olxor(%s)" (size2doc wsize)
  | Olsr wsize -> Format.sprintf "Olsr(%s)" (size2doc wsize)
  | Olsl op -> Format.sprintf "Olsl(%s)" (op_kind2doc op)
  | Oasr op -> Format.sprintf "Oasr(%s)" (op_kind2doc op)
  | Oror wsize -> Format.sprintf "Oror(%s)" (size2doc wsize)
  | Orol wsize -> Format.sprintf "Orol(%s)" (size2doc wsize)
  | Oeq op -> Format.sprintf "Oeq(%s)" (op_kind2doc op)
  | Oneq op -> Format.sprintf "Oneq(%s)" (op_kind2doc op)
  | Olt cmp_kind -> Format.sprintf "Olt(%s)" (cmp_kind2doc cmp_kind)
  | Ole cmp_kind -> Format.sprintf "Ole(%s)" (cmp_kind2doc cmp_kind)
  | Ogt cmp_kind -> Format.sprintf "Ogt(%s)" (cmp_kind2doc cmp_kind)
  | Oge cmp_kind -> Format.sprintf "Oge(%s)" (cmp_kind2doc cmp_kind)
  | Ovadd (_velem, wsize) -> Format.sprintf "Ovadd(_, %s)" (size2doc wsize)
  | Ovsub (_velem, wsize) -> Format.sprintf "Ovsub(_, %s)" (size2doc wsize)
  | Ovmul (_velem, wsize) -> Format.sprintf "Ovmul(_, %s)" (size2doc wsize)
  | Ovlsr (_velem, wsize) -> Format.sprintf "Ovlsr(_, %s)" (size2doc wsize)
  | Ovlsl (_velem, wsize) -> Format.sprintf "Ovlsl(_, %s)" (size2doc wsize)
  | Ovasr (_velem, wsize) -> Format.sprintf "Ovasr(_, %s)" (size2doc wsize)
  | Owi2 (sign, wsize, _op) -> Format.sprintf "Owi2(%s, %s, _)" (sign2doc sign) (size2doc wsize)

let opn2doc : Operators.opN -> string = function
  | Opack (wsize, _pelem) -> Format.sprintf "Opack(%s, _)" (size2doc wsize)
  | Oarray pos -> Format.sprintf "Oarray(%s)" (pos2doc pos)
  | Ocombine_flags _combine_flags -> "Ocombine_flags(_)"

let rec expr2doc : int gexpr -> string = function
  | Pconst z -> Format.sprintf "Pconst(%s)" (z2doc z)
  | Pbool b -> Format.sprintf "Pbool(%s)" (string_of_bool b)
  | Parr_init (wsize, pos) -> Format.sprintf "Parr_init(%s, %s)" (size2doc wsize) (int2doc pos)
  | Pvar ggvar -> Format.sprintf "Pvar(%s)" (ggvar2doc ggvar)
  | Pget (_aligned, _access, wsize, ggvar, expr) ->
    Format.sprintf
      "Pget(_, _, %s, %s, %s)"
      (size2doc wsize) (ggvar2doc ggvar) (expr2doc expr)
  | Psub (_access, wsize, pos, ggvar, expr) ->
    Format.sprintf
      "Psub(_, %s, %s, %s, %s)"
      (size2doc wsize) (int2doc pos) (ggvar2doc ggvar) (expr2doc expr)
  | Pload (_aligned, wsize, expr) -> Format.sprintf "Pload(_, %s, %s)" (size2doc wsize) (expr2doc expr)
  | Papp1 (op, expr) -> Format.sprintf "Papp1(%s, %s)" (unop2doc op) (expr2doc expr)
  | Papp2 (op, e1, e2) -> Format.sprintf "Papp2(%s, %s, %s)" (binop2doc op) (expr2doc e1) (expr2doc e2)
  | PappN (op, _es) -> Format.sprintf "PappN(%s, _)" (opn2doc op)
  | Pif (gtype, cond, then_expr, else_expr) ->
    Format.sprintf
      "Pif(%s, %s, %s, %s)"
      (type2doc gtype) (expr2doc cond) (expr2doc then_expr) (expr2doc else_expr)

(* -------------------------------------------------------------------- *)

let glval2doc : int glval -> string = function
  | Lnone (_info, gtype) -> Format.sprintf "Lnone(_, %s)" (type2doc gtype)
  | Lvar igvar -> Format.sprintf "Lvar(%s)" (igvar2doc igvar)
  | Lmem (_aligned, wsize, _info, expr) -> Format.sprintf "Lmem(_, %s, _, %s)" (size2doc wsize) (expr2doc expr)
  | Laset (_aligned, _access, wsize, igvar, expr) ->
    Format.sprintf "Laset(_, _, %s, %s, %s)" (size2doc wsize) (igvar2doc igvar) (expr2doc expr)
  | Lasub (_access, wsize, len, igvar, expr) ->
    Format.sprintf "Lasub(_, %s, %s, %s, %s)" (size2doc wsize) (int2doc len) (igvar2doc igvar) (expr2doc expr)

(* -------------------------------------------------------------------- *)

let int2string = string_of_int

let z2string z = z |> Z.to_int |> int2string

let size2string : Wsize.wsize -> string = function
  | U32 -> "i32"
  | U64 -> "i64"
  | _ as wsize ->
    wsize
    |> size2doc
    |> Format.sprintf "Don't know how to handle this size : %s"
    |> failwith

let type2string : int gty -> string = function
  | Bty (U wsize) -> size2string wsize
  | Bty Bool
  | Bty Int
  | Arr _ as gtype ->
    gtype
    |> type2doc
    |> Format.sprintf "Don't know how to handle this type : %s"
    |> failwith

let op_kind2string : Operators.op_kind -> string = function
  | Op_w wsize -> size2string wsize
  | Op_int as op_kind ->
    op_kind
    |> op_kind2doc
    |> Format.sprintf "Don't know how to handle this kind of op : %s"
    |> failwith

let sign2string : Wsize.signedness -> string = function
  | Signed -> "s"
  | Unsigned -> "u"

let cmp_kind2string : Operators.cmp_kind -> string * string = function
  | Cmp_w (signedness, wsize) -> (op_kind2string (Op_w wsize), sign2string signedness)
  | Cmp_int as cmp_kind ->
    cmp_kind
    |> cmp_kind2doc
    |> Format.sprintf "Don't know how to handle this kind of cmp : %s"
    |> failwith

let gvar_kind2string (gvar : int gvar) : string =
  if gvar_is_glob gvar then "global" else "local"

let igvar_kind2string (gvar_i : int gvar_i) : string =
  gvar_kind2string gvar_i.pl_desc

let ggvar_kind2string (ggvar : int ggvar) : string =
  igvar_kind2string ggvar.gv

let velem2string : Wsize.velem -> string = function
  | VE8  -> "i8x16"
  | VE16 -> "i16x8"
  | VE32 -> "i32x4"
  | VE64 -> "i64x2"

(* -------------------------------------------------------------------- *)

let opext2string (ws1 : Wsize.wsize) (ws2 : Wsize.wsize) (sign : Wsize.signedness) : string =
  let ws2 =
    match ws1, ws2 with
    | (U32 | U64), U8  -> 8
    | (U32 | U64), U16 -> 16
    |        U64 , U32 -> 32
    | _ ->
      ws2
      |> size2doc
      |> Format.sprintf "Don't know how to handle this size for ext unary operators : %s"
      |> failwith
  in
  Format.sprintf "%s.load%d_%s" (size2string ws1) ws2 (sign2string sign)

let binop2string : Operators.sop2 -> string = function
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
  | Ovasr _ as binop ->
    binop
    |> binop2doc
    |> Format.sprintf "Don't know how to handle this binary operator : %s"
    |> failwith

let rec expr2string : int gexpr -> string = function
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
  | PappN _ as expr ->
    expr
    |> expr2doc
    |> Format.sprintf "Don't know how to handle this expression : %s"
    |> failwith

and unop2string (op : Operators.sop1) (expr : int gexpr) : string =
  (* FIXME : Verify Owi1 operators *)
  match op with
  | Olnot wsize -> Format.sprintf "(%s.xor %s (%s.const -1))" (size2string wsize) (expr2string expr) (size2string wsize)
  | Oneg  op    -> Format.sprintf "(%s.sub (%s.const 0) %s)" (op_kind2string op) (op_kind2string op) (expr2string expr)
  | Owi1 (_sign, WIneg wsize) -> Format.sprintf "(%s.sub (%s.const 0) %s)" (size2string wsize) (size2string wsize) (expr2string expr)
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
      | Owi1 _ as op ->
        op
        |> unop2doc
        |> Format.sprintf "Don't know how to handle this unary operator : %s"
        |> failwith
    in
    Format.sprintf "(%s %s)" op (expr2string expr)

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

(* TODO : source map pour les infos *)
let rec instr2string ({ i_desc ; _ } as instr : (int, 'info, 'asm) ginstr) : string =
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
  | Ccall (glvals, funname, args) ->
    let name = funname.fn_name in
    let args = args |> List.map expr2string |> List.map (Format.sprintf "%s ") |> List.fold_left ( ^ ) "" in
    let call = Format.sprintf "(call $%s %s)" name args in

    let sets =
      glvals
      |> List.map (
           fun (glval : int glval) ->
             match glval with
             | Lnone _ -> "(drop)"
             | Lvar igvar -> Format.sprintf "(%s.set $%s)" (igvar_kind2string igvar) (igvar_name igvar)
             | Lmem (_aligned, wsize, _info, addr) -> Format.sprintf "(%s.store %s)" (size2string wsize) (expr2string addr)
             | _ as glval ->
               glval
               |> glval2doc
               |> Format.sprintf "Don't know how to handle this left-value : %s"
               |> failwith
         )
      |> List.rev
      |> List.fold_left (Format.sprintf "%s@.%s") ""
    in
    Format.sprintf "%s@.%s" call sets
  | Copn (_glvals, _tag, Opseudo_op Onop, _es) -> ""
  | Copn ([Lvar x; Lvar y], _tag, Opseudo_op (Oswap (Coq_aword U32)), [e1; e2]) ->
    Format.sprintf "%s@.%s@.(%s.set $%s)@.(%s.set $%s)" (expr2string e1) (expr2string e2) (igvar_kind2string x) (igvar_name x) (igvar_kind2string y) (igvar_name y)
  | Cassgn _
  | Copn _
  | Csyscall _
  | Cassert _
  | Cfor _ ->
    let module Core = CoreArchFactory.Core_arch_WASM in
    let module Arch = Arch_full.Arch_from_Core_arch_wasm (Core) in
    Format.asprintf "Don't know how to handle this instruction : %a" (Printer.pp_instr ~debug:false U32 U32 Arch.asmOp) instr
    |> failwith

and instrs2string (instrs : (int, 'info, 'asm) ginstr list) : string =
  instrs
  |> List.map instr2string
  |> List.map (Format.sprintf "%s@.")
  |> List.fold_left ( ^ ) ""

let pp_instr : string -> string =
  Format.sprintf "%s@."

(* -------------------------------------------------------------------- *)

type fun_vars =
  { locals  : int gvar list ;
    globals : int gvar list }

let collect_fun_vars (func : ('info, 'asm) func) : fun_vars =
  let gvars = func |> Prog.locals |> Sv.to_list in
  let locals  = List.filter gvar_is_local gvars in
  let globals = List.filter gvar_is_glob  gvars in
  { locals ; globals }

let compile_func ((_extra, func) : ('info, 'asm) sfundef) : int gvar list * (string * string) =
  let def_name = func.f_name.fn_name in
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
  let { locals ; globals } = collect_fun_vars func in
  let def_locals =
    locals
    |> List.map (
         fun gvar ->
           Format.sprintf "(local $%s %s)" (gvar_name gvar) (type2string (gvar_type gvar))
       )
    |> List.map (Format.sprintf "%s@.")
    |> List.fold_left ( ^ ) ""
  in
  let def_body = func.f_body |> instrs2string |> pp_instr in
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

  (globals, (def, export))

let compile_funcs (p_funcs : ('info, 'asm) sfundef list) : int gvar list * (string * string) list =
  let (globals_list, compiled_funcs) = p_funcs |> List.map compile_func |> List.split in
  (List.flatten globals_list, compiled_funcs)

let pp_func ((def, export) : string * string) : string =
  Format.sprintf "%s@.%s@." def export

let pp_funcs : (string * string) list -> string = function
  | [] -> ""
  | [ f ] -> pp_func f
  | l ->
    let def = l |> List.map fst |> List.map (Format.sprintf "%s@.") |> List.fold_left ( ^ ) "" in
    let export = l |> List.map snd |> List.map (Format.sprintf "%s@.") |> List.fold_left ( ^ ) "" in
    pp_func (def, export)

(* -------------------------------------------------------------------- *)

let default_value : int gty -> (Wsize.wsize * int) = function
  | Bty (U wsize) -> (wsize, 0)
  | Bty Bool
  | Bty Int
  | Arr _ as gtype ->
    gtype
    |> type2doc
    |> Format.sprintf "Don't know how to get a default value from this type : %s"
    |> failwith

let compile_glob (gvar : int gvar) : string =
  let (wsize, value) = default_value (gvar_type gvar) in
  Format.sprintf "(global $%s (mut %s) (%s.const %s))" (gvar_name gvar) (size2string wsize) (size2string wsize) (int2string value)

let compile_globs (globs : int gvar list) : string list =
  List.map compile_glob globs

let pp_glob : string -> string =
  Format.sprintf "%s@."

let pp_globs (l : string list) : string =
  l |> List.map pp_glob |> List.fold_left ( ^ ) ""

(* -------------------------------------------------------------------- *)

let pp_prog (funcs : ('info, 'asm) sfundef list) : unit =
  let globs, compiled_funcs = compile_funcs funcs in
  let printed_funcs = pp_funcs compiled_funcs in

  let printed_globs = globs |> compile_globs |> pp_globs in

  let printed_memory = Format.sprintf {|(import "env" "memory" (memory 1))|} in

  Format.printf {|@.(module@.%s@.%s@.%s)@.|} printed_memory printed_globs printed_funcs (* FIXME: Verify this import for the memory *)

(* -------------------------------------------------------------------- *)

let compiler_back_end (sprog : ('reg, 'regx, 'xreg, 'rflag, 'cond, 'asm_op, 'extra_op) Arch_extra.extended_op Expr._sprog) : unit =
  if !debug then begin
    Format.eprintf "/* -------------------------------------------------------------------- */@.";
    Format.eprintf "/* START WASM back_end */@."
  end;

  let (funcs, _extra) = Conv.prog_of_csprog sprog in
  pp_prog funcs;

  if !debug then begin
    Format.eprintf "/* END WASM back_end */@.";
    Format.eprintf "/* -------------------------------------------------------------------- */@."
  end;

(* Type for data *)
type data = {
  names : string list;
  values : (value_kind, float list) Hashtbl.t;
}

and kind_algo =
  | Ref
  | Opt
  | Both

and value_kind =
  | Ratio_OPT3_OPT4
  | Ratio_AS_OPT
  | Ratio_AS_X86
  | Ratio_OPT3_X86
  | Ratio_OPT4_X86
  | Ratio_WASM_X86

(* Utils functions *)
let kind_of_string = function
  | "false" -> Ref
  | "true" -> Opt
  | "both" -> Both
  | str ->
    str
    |> Format.sprintf "%s is an Incorrect string for a kind_algo"
    |> failwith


let have_to_save only_opt kind =
  if only_opt then kind = Both || kind = Opt else kind = Both || kind = Ref


let filter_lines only_opt lines =
  List.filter
    (fun line -> List.nth line 1 |> kind_of_string |> have_to_save only_opt)
    lines


let rename_names str =
  let l = String.split_on_char ' ' str in
  let prefix =
    match List.hd l with
    | "GIMLI" -> "GIMLI"
    | "SHA256" -> "SHA256"
    | "SHA256-OPT" -> "SHA256-opt"
    | "CHACHA20" -> "CHACHA20"
    | "CHACHA20-OPT" -> "CHACHA20-opt"
    | "CHACHA20AVX" -> "CHACHA20\\_AVX"
    | "CHACHA20AVX-OPT" -> "CHACHA20\\_AVX-opt"
    | "CHACHA20XOR" -> "CHACHA20\\_XOR"
    | "CHACHA20XOR-OPT" -> "CHACHA20\\_XOR-opt"
    | "CHACHA20XORAVX" -> "CHACHA20\\_AVX\\_XOR"
    | "CHACHA20XORAVX-OPT" -> "CHACHA20\\_AVX\\_XOR-opt"
    | prefix -> prefix
  in
  let l = prefix :: List.tl l in
  String.concat " " l


let extract_line lines idx = List.map (fun l -> List.nth l idx) lines

(* Make data from the file content *)
let make_data lines only_opt =
  let lines = filter_lines only_opt (List.tl lines) in
  let extract_line = extract_line lines in
  let float_of_line idx = List.map float_of_string (extract_line idx) in

  let names =
    extract_line 0 |> List.map String.uppercase_ascii |> List.map rename_names
  in

  let values = Hashtbl.create 16 in
  Hashtbl.replace values Ratio_OPT3_OPT4 (float_of_line 2);
  Hashtbl.replace values Ratio_AS_OPT (float_of_line 3);
  Hashtbl.replace values Ratio_AS_X86 (float_of_line 4);
  Hashtbl.replace values Ratio_OPT3_X86 (float_of_line 5);
  Hashtbl.replace values Ratio_OPT4_X86 (float_of_line 6);
  Hashtbl.replace values Ratio_WASM_X86 (float_of_line 7);

  { names; values }

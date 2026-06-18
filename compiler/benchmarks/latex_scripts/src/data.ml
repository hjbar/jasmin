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
  (* Ratio with Node *)
  | Ratio_Opt3Node_Opt4Node
  | Ratio_AsNode_OptNode
  | Ratio_AsNode_X86
  | Ratio_Opt3Node_X86
  | Ratio_Opt4Node_X86
  | Ratio_WasmNode_X86
  (* Ratio with Firefox *)
  | Ratio_Opt3Firefox_Opt4Firefox
  | Ratio_AsFirefox_OptFirefox
  | Ratio_AsFirefox_X86
  | Ratio_Opt3Firefox_X86
  | Ratio_Opt4Firefox_X86
  | Ratio_WasmFirefox_X86
  (* Ratio with All *)
  | Ratio_AsNode_AsFirefox
  | Ratio_Opt3Node_Opt3Firefox
  | Ratio_Opt4Node_Opt4Firefox
  | Ratio_WasmNode_WasmFirefox
  | Ratio_Wasm_X86

(* Global values *)
let value_kinds =
  [
    (* Ratio with Node *)
    Ratio_Opt3Node_Opt4Node;
    Ratio_AsNode_OptNode;
    Ratio_AsNode_X86;
    Ratio_Opt3Node_X86;
    Ratio_Opt4Node_X86;
    Ratio_WasmNode_X86;
    (* Ratio with Firefox *)
    Ratio_Opt3Firefox_Opt4Firefox;
    Ratio_AsFirefox_OptFirefox;
    Ratio_AsFirefox_X86;
    Ratio_Opt3Firefox_X86;
    Ratio_Opt4Firefox_X86;
    Ratio_WasmFirefox_X86;
    (* Ratio with All *)
    Ratio_AsNode_AsFirefox;
    Ratio_Opt3Node_Opt3Firefox;
    Ratio_Opt4Node_Opt4Firefox;
    Ratio_WasmNode_WasmFirefox;
    Ratio_Wasm_X86;
  ]


let value_kinds_node =
  [
    Ratio_Opt3Node_Opt4Node;
    Ratio_AsNode_OptNode;
    Ratio_AsNode_X86;
    Ratio_Opt3Node_X86;
    Ratio_Opt4Node_X86;
    Ratio_WasmNode_X86;
  ]


let value_kinds_firefox =
  [
    Ratio_Opt3Firefox_Opt4Firefox;
    Ratio_AsFirefox_OptFirefox;
    Ratio_AsFirefox_X86;
    Ratio_Opt3Firefox_X86;
    Ratio_Opt4Firefox_X86;
    Ratio_WasmFirefox_X86;
  ]


let value_kinds_all =
  [
    Ratio_AsNode_AsFirefox;
    Ratio_Opt3Node_Opt3Firefox;
    Ratio_Opt4Node_Opt4Firefox;
    Ratio_WasmNode_WasmFirefox;
    Ratio_Wasm_X86;
  ]


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
  List.iteri
    (fun i kind -> Hashtbl.replace values kind (float_of_line (i + 2)))
    value_kinds;

  { names; values }

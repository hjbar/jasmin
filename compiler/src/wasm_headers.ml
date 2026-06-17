open Wasm_utils

(* Types *)

type wasm_headers = {
  mem_header : string;
  import_header : string;
  data_header : string;
  decl_header : string;
  func_header : string;
  init_header : string;
  export_header : string;
  start_header : string;
}


(* Utils *)

let rec find_root dir =
  if Sys.file_exists (Filename.concat dir "jasminc") then
    dir
  else
    let parent = Filename.dirname dir in
    if parent = dir then dir
    else find_root parent

let get_root () =
  Sys.executable_name |> Filename.dirname |> find_root

let wsize_to_string : Wsize.wsize -> string = function
  | U8 -> "i8"
  | U16 -> "i16"
  | U32 -> "i32"
  | U64 -> "i64"
  | U128 -> "v128"
  | U256 -> assert false

let gen_content root path =
  let path = Filename.concat root path in
  let command = Format.sprintf "bash %s" path in
  if Sys.command command <> 0 then begin
    Format.eprintf "Fail to run %s\n" path;
    exit 1
  end

let parse_content root fmt =
  List.map (fun s ->
    let in_c = s |> Format.sprintf fmt |> Filename.concat root |> open_in in
    let content = In_channel.input_all in_c in
    close_in in_c;
    content
  )

let concat_content content sep =
  content |> List.flatten |> String.concat sep


(* Compute mem header *)

let compute_mem () = ""


(* Compute import header *)

let compute_import () = ""


(* Compute data header *)

let compute_data () = ""


(* Compute decl header *)

let compute_decl () = ""


(* Compute func header *)

let compute_func root array_used =
  gen_content root "headers/templates/array_funcs_gen.sh";
  let array_funcs = parse_content root "headers/array_funcs_%s.txt" array_used in
  concat_content [ array_funcs ] "\n"


(* Compute init header *)

let compute_init () = ""


(* Compute export header *)

let compute_export root array_used =
  gen_content root "headers/templates/array_exports_gen.sh";
  let array_exports = parse_content root "headers/array_exports_%s.txt" array_used in
  concat_content [ array_exports ] ""


(* Compute start header *)

let compute_start () = ""


(* Compute wasm headers *)

let compute_headers fs =
  let root = get_root () in

  let array_used =
    [ U8; U16; U32; U64; U128 ]
    |> List.filter (fun wsize -> has_ref_fs wsize fs)
    |> List.map wsize_to_string
  in

  let mem_header = compute_mem () in
  let import_header = compute_import () in
  let data_header = compute_data () in
  let decl_header = compute_decl () in
  let func_header = compute_func root array_used in
  let init_header = compute_init () in
  let export_header = compute_export root array_used in
  let start_header = compute_start () in

  { mem_header; import_header; data_header; decl_header; func_header; init_header; export_header; start_header }

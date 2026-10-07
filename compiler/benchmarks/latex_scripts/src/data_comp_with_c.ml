(* Type for data *)
type data = {
  names : string list;
  values : (value_kind, float list) Hashtbl.t;
}

and value_kind =
  (* Ratio with All *)
  | Ratio_CExe_JazzExe
  | Ratio_CWasm_JazzWasm

(* Global values *)
let value_kinds = [ Ratio_CExe_JazzExe; Ratio_CWasm_JazzWasm ]

(* Utils functions *)
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

(* Reoder by input length each algorithms *)
type label = {
  fullname : string;
  algo : string;
  input_size : int;
}

let parse_label fullname =
  match
    String.(
      List.(
        fullname
        |> split_on_char '('
        |> map (split_on_char ')')
        |> map (map trim) ) )
  with
  | [ [ algo ]; [ input_size; "" ] ] ->
    { fullname; algo; input_size = int_of_string input_size }
  | _ -> exit 1


let sort_labels labels =
  let parsed = List.map parse_label labels in

  let algo_order = Hashtbl.create 16 in
  let cpt = ref ~-1 in
  List.iter
    (fun { algo; _ } ->
      if not (Hashtbl.mem algo_order algo) then begin
        incr cpt;
        Hashtbl.replace algo_order algo !cpt
      end )
    parsed;

  let compare lab1 lab2 =
    let order1 = Hashtbl.find algo_order lab1.algo in
    let order2 = Hashtbl.find algo_order lab2.algo in
    if order1 <> order2 then compare order1 order2
    else compare lab1.input_size lab2.input_size
  in

  parsed |> List.sort compare |> List.map (fun lab -> lab.fullname)


let sort_lines lines =
  let sorted_labels = sort_labels (extract_line lines 0) in
  let htbl_label = Hashtbl.create 16 in
  List.iter (fun line -> Hashtbl.replace htbl_label (List.hd line) line) lines;
  List.map (Hashtbl.find htbl_label) sorted_labels


(* Make data from the file content *)
let make_data lines =
  let lines = lines |> List.tl |> sort_lines in
  let extract_line = extract_line lines in
  let float_of_line idx = List.map float_of_string (extract_line idx) in

  let names =
    extract_line 0 |> List.map String.uppercase_ascii |> List.map rename_names
  in

  let values = Hashtbl.create 16 in
  List.iteri
    (fun i kind -> Hashtbl.replace values kind (float_of_line (i + 6)))
    value_kinds;

  { names; values }

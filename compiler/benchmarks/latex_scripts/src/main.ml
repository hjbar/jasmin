(* Parsing functions *)
let parse_command_line () =
  let parsed_args = ref [] in

  let speclist = [] in
  let usage_msg = "Usage: dune exec src/main.exe -- <file> <kind>" in
  Arg.parse speclist (fun arg -> parsed_args := arg :: !parsed_args) usage_msg;

  match !parsed_args with
  | [ (("backends" | "comp_with_c") as kind); filename ] -> (filename, kind)
  | _ ->
    Arg.usage speclist usage_msg;
    exit 1


let parse_file filename =
  let in_c = open_in filename in
  let lines =
    in_c |> In_channel.input_lines |> List.map (String.split_on_char ';')
  in
  close_in in_c;
  lines


(* Main *)
let () =
  let filename, kind = parse_command_line () in
  let lines = parse_file filename in

  match kind with
  | "backends" -> Main_backends.main lines
  | "comp_with_c" -> Main_comp_with_c.main lines
  | _ -> exit 1

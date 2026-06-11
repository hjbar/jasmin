open Data
open Plot

(* Command line *)
let parse_command_line () =
  let filename = ref "" in

  let speclist = [] in
  let usage_msg = "Usage: dune exec src/main.exe -- <file>" in
  Arg.parse speclist (fun arg -> filename := arg) usage_msg;

  if !filename = "" then begin
    Arg.usage speclist usage_msg;
    exit 1
  end;

  !filename


(* Utils functions *)
let dispatch_make_plot = function
  | Ratio_OPT3_OPT4 -> make_Ratio_OPT3_OPT4_plot
  | Ratio_AS_OPT -> make_Ratio_AS_OPT_plot
  | Ratio_AS_X86 -> make_Ratio_AS_X86_plot
  | Ratio_OPT3_X86 -> make_Ratio_OPT3_X86_plot
  | Ratio_OPT4_X86 -> make_Ratio_OPT4_X86_plot
  | Ratio_WASM_X86 -> make_Ratio_WASM_X86_plot


let compute_plot only_opt value_kind lines =
  let str_kind = if only_opt then "optimisées" else "minimales" in
  let make_plot_func = dispatch_make_plot value_kind in

  let plot =
    Plot.print_plot (make_plot_func str_kind (Data.make_data lines only_opt))
  in
  Format.printf "\n\n%s\n\n" plot


(* Main *)
let () =
  let filename = parse_command_line () in
  let in_c = open_in filename in
  let lines =
    in_c |> In_channel.input_lines |> List.map (String.split_on_char ';')
  in
  close_in in_c;

  let value_kinds =
    [
      Ratio_OPT3_OPT4;
      Ratio_AS_OPT;
      Ratio_AS_X86;
      Ratio_OPT3_X86;
      Ratio_OPT4_X86;
      Ratio_WASM_X86;
    ]
  in
  let false_value_kind =
    List.map (fun value_kind -> (false, value_kind)) value_kinds
  in
  let true_value_kind =
    List.map (fun value_kind -> (true, value_kind)) value_kinds
  in

  List.iter
    (fun (only_opt, value_kind) -> compute_plot only_opt value_kind lines)
    (false_value_kind @ true_value_kind)

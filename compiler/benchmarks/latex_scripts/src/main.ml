open Data
open Plot

(* Parsing functions *)
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


let parse_file filename =
  let in_c = open_in filename in
  let lines =
    in_c |> In_channel.input_lines |> List.map (String.split_on_char ';')
  in
  close_in in_c;
  lines


(* Compute plots functions *)
let dispatch_make_plot = function
  (* Ratio with Node *)
  | Ratio_Opt3Node_Opt4Node -> make_Ratio_Opt3Node_Opt4Node_plot
  | Ratio_AsNode_OptNode -> make_Ratio_AsNode_OptNode_plot
  | Ratio_AsNode_X86 -> make_Ratio_AsNode_X86_plot
  | Ratio_Opt3Node_X86 -> make_Ratio_Opt3Node_X86_plot
  | Ratio_Opt4Node_X86 -> make_Ratio_Opt4Node_X86_plot
  | Ratio_WasmNode_X86 -> make_Ratio_WasmNode_X86_plot
  (* Ratio with Firefox *)
  | Ratio_Opt3Firefox_Opt4Firefox -> make_Ratio_Opt3Firefox_Opt4Firefox_plot
  | Ratio_AsFirefox_OptFirefox -> make_Ratio_AsFirefox_OptFirefox_plot
  | Ratio_AsFirefox_X86 -> make_Ratio_AsFirefox_X86_plot
  | Ratio_Opt3Firefox_X86 -> make_Ratio_Opt3Firefox_X86_plot
  | Ratio_Opt4Firefox_X86 -> make_Ratio_Opt4Firefox_X86_plot
  | Ratio_WasmFirefox_X86 -> make_Ratio_WasmFirefox_X86_plot
  (* Ratio with All *)
  | Ratio_AsNode_AsFirefox -> make_Ratio_AsNode_AsFirefox_plot
  | Ratio_Opt3Node_Opt3Firefox -> make_Ratio_Opt3Node_Opt3Firefox_plot
  | Ratio_Opt4Node_Opt4Firefox -> make_Ratio_Opt4Node_Opt4Firefox_plot
  | Ratio_WasmNode_WasmFirefox -> make_Ratio_WasmNode_WasmFirefox_plot
  | Ratio_Wasm_X86 -> make_Ratio_Wasm_X86_plot


let compute_plot lines (only_opt, value_kind) =
  let str_kind = if only_opt then "optimisées" else "minimales" in
  let make_plot_func = dispatch_make_plot value_kind in

  let plot =
    Plot.print_plot ~force:true
      (make_plot_func str_kind (Data.make_data lines only_opt))
  in
  Format.printf "\n\n%s\n\n" plot


let compute_plots lines = List.iter (compute_plot lines)

let compute_plots_only_opt only_opt lines kinds =
  compute_plots lines (List.map (fun kind -> (only_opt, kind)) kinds)


(* Printing functions *)
let print_newpage () = Format.printf "\n\n\n\\newpage\n\n\n%!"

let print_section title = Format.printf "\n\n\\section{%s}\n\n%!" title

let print_subsection subtitle = Format.printf "\n\\subsection{%s}\n%!" subtitle

(* Main *)
let () =
  let filename = parse_command_line () in
  let lines = parse_file filename in

  print_section "Versions minimales";
  print_subsection "Mesures avec Node";
  compute_plots_only_opt false lines value_kinds_node;
  print_subsection "Mesures avec Firefox";
  compute_plots_only_opt false lines value_kinds_firefox;
  print_subsection "Mesures avec All";
  compute_plots_only_opt false lines value_kinds_all;

  print_newpage ();

  print_section "Versions optimisées";
  print_subsection "Mesures avec Node";
  compute_plots_only_opt true lines value_kinds_node;
  print_subsection "Mesures avec Firefox";
  compute_plots_only_opt true lines value_kinds_firefox;
  print_subsection "Mesures avec All";
  compute_plots_only_opt true lines value_kinds_all

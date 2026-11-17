(* Type for plots *)
type plot = {
  table : string list list;
  label : string;
  ylabel : string;
  precision : int;
  sort : sort;
  axis : string list;
  legends : string list;
  max : float;
  caption : string;
  fig : string;
}

and sort = {
  sort_label : string;
  sort_option : string;
}

(* Utils functions *)
let fresh_fig =
  let cpt = ref ~-1 in
  fun () ->
    incr cpt;
    Format.sprintf "bench%d" !cpt


let round_max max = (floor (max *. 20.) +. 5.) /. 20.

let compute_round_max_times l =
  l
  |> List.map (fun (_, (val1, val2)) -> max val1 val2)
  |> List.fold_left max 0.
  |> ( *. ) 1.05
  |> round_max


let take_drop_n n l =
  match List.take n l with
  | exception exn -> raise exn
  | values ->
    begin match List.drop n l with
    | exception _ -> (values, l)
    | l -> (values, l)
    end


let take_drop_1 = take_drop_n 1

let take_drop_3 = take_drop_n 3

(* Make plots from data *)
let make_times_plot algo values =
  let cpt = ref ~-1 in

  let id_name = "ID" in
  let label_name = "Labels" in
  let val1_name = "NODEFIREFOX" in
  let val2_name = "WASMTIME" in

  let first_line = [ id_name; label_name; val1_name; val2_name ] in
  let other_lines =
    List.map
      (fun (name, (val1, val2)) ->
        incr cpt;
        Format.
          [
            sprintf "%d" !cpt;
            sprintf "{%s}" name;
            sprintf "%f" val1;
            sprintf "%f" val2;
          ] )
      values
  in
  let table = first_line :: other_lines in

  let label = label_name in
  let ylabel = "Temps (en microsecondes)" in
  let precision = 2 in
  let sort_label = id_name in
  let sort_option = "" in
  let sort = { sort_label; sort_option } in

  let axis = [ val1_name; val2_name ] in
  let max = compute_round_max_times values in

  let legends = [ "Node+Firefox"; "Wasmtime" ] in
  let caption =
    Format.sprintf
      "Comparaison des temps d'exécution pour %s entre Node+Firefox et Wasmtime"
      algo
  in
  let fig = fresh_fig () in

  { table; label; ylabel; precision; sort; axis; legends; max; caption; fig }


let make_times_plot Data_comp_with_wasmtime.{ names; values } =
  let lookup_to_microseconds kind =
    Hashtbl.find values kind |> List.map (fun f -> f /. 1000.)
  in

  let times_nodefirefox =
    lookup_to_microseconds Data_comp_with_wasmtime.Time_NodeFirefox
  in
  let times_wasmtime =
    lookup_to_microseconds Data_comp_with_wasmtime.Time_Wasmtime
  in

  let times = List.combine times_nodefirefox times_wasmtime in
  let all = List.combine names times in

  let gimli, all = take_drop_1 all in
  let sha256, all = take_drop_3 all in
  let chacha20, all = take_drop_3 all in
  let chacha20_avx, all = take_drop_3 all in
  let chacha20_xor, all = take_drop_3 all in
  let chacha20_xor_avx, _all = take_drop_3 all in

  [
    make_times_plot "gimli" gimli;
    make_times_plot "sha256" sha256;
    make_times_plot "chacha20" chacha20;
    make_times_plot "chacha20avx" chacha20_avx;
    make_times_plot "chacha20xor" chacha20_xor;
    make_times_plot "chacha20xoravx" chacha20_xor_avx;
  ]


let make_ratio_plot legends caption Data_comp_with_wasmtime.{ names; values } =
  let cpt = ref ~-1 in

  let id_name = "ID" in
  let label_name = "Labels" in
  let val_name = "Values" in

  let values =
    Hashtbl.find values Data_comp_with_wasmtime.Ratio_Wasmtime_NodeFirefox
  in

  let first_line = [ id_name; label_name; val_name ] in
  let other_lines =
    List.map2
      (fun name value ->
        incr cpt;
        Format.[ sprintf "%d" !cpt; sprintf "{%s}" name; sprintf "%.4f" value ] )
      names values
  in
  let table = first_line :: other_lines in

  let label = label_name in
  let ylabel = "Ratio" in
  let precision = 2 in
  let sort_label = val_name in
  let sort_option = "" in
  let sort = { sort_label; sort_option } in

  let axis = [ val_name ] in

  let max = round_max (List.fold_left max 0. values +. 0.05) in

  let fig = fresh_fig () in

  { table; label; ylabel; precision; sort; axis; legends; max; caption; fig }


(* Print plot *)
let string_of_table table =
  let l1 = "\\pgfplotstableread{" in
  let lines =
    table
    |> List.map (String.concat " ")
    |> List.fold_left (Format.sprintf "%s\n%s") ""
  in
  let l2 = "}\\datatable\\" in

  Format.sprintf "%s\n%s\n%s\n" l1 lines l2


let string_of_sort { sort_label; sort_option } =
  Format.sprintf
    "\\pgfplotstablesort[sort key={%s}, %s]{\\sortedtable}{\\datatable}\n"
    sort_label sort_option


let string_of_config label ylabel max precision =
  Format.sprintf
    "\\begin{axis}[\n\
    \          ybar,\n\
    \          bar width=0.5cm,\n\
    \          width=1.5\\textwidth,\n\
    \          height=8cm,\n\
    \          ylabel={%s},\n\
    \          xtick=data,\n\
    \          xticklabels from table={\\sortedtable}{%s},\n\
    \          xticklabel style={rotate=90, anchor=east, font=\\small},\n\
    \          enlarge x limits=0.05,\n\
    \          ymin=0, ymax=%.2f,\n\
    \          ymajorgrids=true,\n\
    \          legend style={\n\
    \            at={(0.0, 1.0)},\n\
    \            anchor=north west,\n\
    \            legend columns=1,\n\
    \            font=\\small\n\
    \          },\n\
    \          nodes near coords,\n\
    \          nodes near coords style={\n\
    \            font=\\scriptsize\\bfseries,\n\
    \            color=black,\n\
    \            rotate=90,\n\
    \            anchor=west,\n\
    \            xshift=-0.8cm\n\
    \          },\n\
    \          /pgf/number format/.cd,\n\
    \          fixed,\n\
    \          precision=%d,\n\
    \          zerofill\n\
    \        ]\n"
    ylabel label max precision


let string_of_axis =
  Format.sprintf
    "\\addplot table [x expr=\\coordindex, y=%s] {\\sortedtable};\n"


let string_of_axiss axiss =
  axiss |> List.map string_of_axis |> String.concat "\n"


let string_of_legends legends =
  legends |> String.concat "," |> Format.sprintf "\\legend{%s}\n"


let print_plot
  ?(force = false)
  { table; label; ylabel; precision; sort; axis; legends; max; caption; fig } =
  Format.sprintf
    "\\begin{figure}[%s]\n\
    \   \\centering\n\
    \   %s\n\
    \   %s\n\
    \   \\begin{adjustbox}{max width=\\textwidth}\n\
    \      \\begin{tikzpicture}\n\
    \         %s\n\
    \         %s\n\
    \         %s\n\
    \         \\end{axis}\n\
    \      \\end{tikzpicture}\n\
    \   \\end{adjustbox}\n\
    \   \\caption{%s}\n\
    \   \\label{fig:%s}\n\
     \\end{figure}\n"
    (if force then "H" else "htbp")
    (string_of_table table) (string_of_sort sort)
    (string_of_config label ylabel max precision)
    (string_of_axiss axis)
    (string_of_legends legends)
    caption fig

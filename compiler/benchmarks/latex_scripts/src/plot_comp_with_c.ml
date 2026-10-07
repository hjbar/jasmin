(* Type for plots *)
type plot = {
  table : string list list;
  label : string;
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


let round_max max = (floor (max *. 20.) +. 1.) /. 20.

(* Make plots from data *)
let make_single_plot legends caption Data_comp_with_c.{ names; values } =
  let cpt = ref ~-1 in

  let id_name = "ID" in
  let label_name = "Labels" in
  let val1_name = "Val1" in
  let val2_name = "Val2" in

  let values1 = Hashtbl.find values Data_comp_with_c.Ratio_CExe_JazzExe in
  let values2 = Hashtbl.find values Data_comp_with_c.Ratio_CWasm_JazzWasm in
  let values = List.combine values1 values2 in

  let first_line = [ id_name; label_name; val1_name; val2_name ] in
  let other_lines =
    List.map2
      (fun name (val1, val2) ->
        incr cpt;
        Format.
          [
            sprintf "%d" !cpt;
            sprintf "{%s}" name;
            sprintf "%.4f" val1;
            sprintf "%.4f" val2;
          ] )
      names values
  in
  let table = first_line :: other_lines in

  let label = label_name in
  let sort_label = id_name in
  let sort_option = "" in
  let sort = { sort_label; sort_option } in

  let axis = [ val1_name; val2_name ] in

  let max =
    max
      (round_max (List.fold_left max 0. values1 +. 0.05))
      (round_max (List.fold_left max 0. values2 +. 0.05))
  in

  let fig = fresh_fig () in

  { table; label; sort; axis; legends; max; caption; fig }


(* Make plots from Node values *)
let make_plot =
  make_single_plot
    [ "Ratio C-->exe / Jazz-->x86-->exe"; "Ratio C-->Wasm / Jazz-->Wasm" ]
    "Comparaison des temps d'exécution entre C et Jasmin"


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


let string_of_config label max =
  Format.sprintf
    "\\begin{axis}[\n\
    \          ybar,\n\
    \          bar width=0.5cm,\n\
    \          width=1.5\\textwidth,\n\
    \          height=8cm,\n\
    \          ylabel={Ratio},\n\
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
    \          precision=2,\n\
    \          zerofill\n\
    \        ]\n"
    label max


let string_of_axis =
  Format.sprintf
    "\\addplot table [x expr=\\coordindex, y=%s] {\\sortedtable};\n"


let string_of_axiss axiss =
  axiss |> List.map string_of_axis |> String.concat "\n"


let string_of_legends legends =
  legends |> String.concat "," |> Format.sprintf "\\legend{%s}\n"


let print_plot
  ?(force = false) { table; label; sort; axis; legends; max; caption; fig } =
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
    (string_of_config label max)
    (string_of_axiss axis)
    (string_of_legends legends)
    caption fig

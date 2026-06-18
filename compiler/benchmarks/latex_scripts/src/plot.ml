(* Type for plots *)
type plot = {
  table : string list list;
  label : string;
  sort : string;
  axis : axis list;
  max : float;
  caption : string;
  fig : string;
}

and axis = {
  number_label : string;
  legend : string;
}

(* Utils functions *)
let fresh_fig =
  let cpt = ref ~-1 in
  fun () ->
    incr cpt;
    Format.sprintf "bench%d" !cpt


let round_max max = (floor (max *. 20.) +. 1.) /. 20.

(* Make plots from data *)
let make_single_plot value_kind legend caption Data.{ names; values } =
  let numbers = Hashtbl.find values value_kind in

  let first_line = [ "Labels"; "Values" ] in
  let other_lines =
    List.map2
      (fun name value ->
        [ Format.sprintf "{%s}" name; Format.sprintf "%.4f" value ] )
      names numbers
  in
  let table = first_line :: other_lines in

  let label = "Labels" in
  let sort = "Values" in

  let number_label = "Values" in
  let axis = [ { number_label; legend } ] in

  let max = round_max (List.fold_left max 0. numbers +. 0.05) in

  let fig = fresh_fig () in

  { table; label; sort; axis; max; caption; fig }


(* Make plots from Node values *)
let make_Ratio_Opt3Node_Opt4Node_plot kind_string =
  make_single_plot Ratio_Opt3Node_Opt4Node
    "Ratio wasm-opt -O3 [Node] / wasm-opt -O4 [Node]"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-opt \
        -O3 [Node] et wasm-opt -O4 [Node]"
       kind_string )


let make_Ratio_AsNode_OptNode_plot kind_string =
  make_single_plot Ratio_AsNode_OptNode
    "Ratio wasm-as [Node] / best-wasm-opt [Node]"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-as \
        [Node] et best-wasm-opt [Node]"
       kind_string )


let make_Ratio_AsNode_X86_plot kind_string =
  make_single_plot Ratio_AsNode_X86 "Ratio wasm-as [Node] / X86-64"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-as \
        [Node] et X86-64"
       kind_string )


let make_Ratio_Opt3Node_X86_plot kind_string =
  make_single_plot Ratio_Opt3Node_X86 "Ratio wasm-opt -O3 [Node] / X86-64"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-opt \
        -O3 [Node] et X86-64"
       kind_string )


let make_Ratio_Opt4Node_X86_plot kind_string =
  make_single_plot Ratio_Opt4Node_X86 "Ratio wasm-opt -O4 [Node] / X86-64"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-opt \
        -O4 [Node] et X86-64"
       kind_string )


let make_Ratio_WasmNode_X86_plot kind_string =
  make_single_plot Ratio_WasmNode_X86 "Ratio best-Wasm [Node] / X86-64"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre best-Wasm \
        [Node] et X86-64"
       kind_string )


(* Make plots from Firefox values *)
let make_Ratio_Opt3Firefox_Opt4Firefox_plot kind_string =
  make_single_plot Ratio_Opt3Firefox_Opt4Firefox
    "Ratio wasm-opt -O3 [Firefox] / wasm-opt -O4 [Firefox]"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-opt \
        -O3 [Firefox] et wasm-opt -O4 [Firefox]"
       kind_string )


let make_Ratio_AsFirefox_OptFirefox_plot kind_string =
  make_single_plot Ratio_AsFirefox_OptFirefox
    "Ratio wasm-as [Firefox] / best-wasm-opt [Firefox]"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-as \
        [Firefox] et best-wasm-opt [Firefox]"
       kind_string )


let make_Ratio_AsFirefox_X86_plot kind_string =
  make_single_plot Ratio_AsFirefox_X86 "Ratio wasm-as [Firefox] / X86-64"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-as \
        [Firefox] et X86-64"
       kind_string )


let make_Ratio_Opt3Firefox_X86_plot kind_string =
  make_single_plot Ratio_Opt3Firefox_X86 "Ratio wasm-opt -O3 [Firefox] / X86-64"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-opt \
        -O3 [Firefox] et X86-64"
       kind_string )


let make_Ratio_Opt4Firefox_X86_plot kind_string =
  make_single_plot Ratio_Opt4Firefox_X86 "Ratio wasm-opt -O4 [Firefox] / X86-64"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-opt \
        -O4 [Firefox] et X86-64"
       kind_string )


let make_Ratio_WasmFirefox_X86_plot kind_string =
  make_single_plot Ratio_WasmFirefox_X86 "Ratio best-Wasm [Firefox] / X86-64"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre best-Wasm \
        [Firefox] et X86-64"
       kind_string )


(* Make plots from All values *)
let make_Ratio_AsNode_AsFirefox_plot kind_string =
  make_single_plot Ratio_AsNode_AsFirefox
    "Ratio wasm-as [Node] / wasm-as [Firefox]"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-as \
        [Node] et wasm-as [Firefox]"
       kind_string )


let make_Ratio_Opt3Node_Opt3Firefox_plot kind_string =
  make_single_plot Ratio_Opt3Node_Opt3Firefox
    "Ratio wasm-opt -O3 [Node] / wasm-opt -O3 [Firefox]"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-opt \
        -O3 [Node] et wasm-opt -O3 [Firefox]"
       kind_string )


let make_Ratio_Opt4Node_Opt4Firefox_plot kind_string =
  make_single_plot Ratio_Opt4Node_Opt4Firefox
    "Ratio wasm-opt -O4 [Node] / wasm-opt -O4 [Firefox]"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre wasm-opt \
        -O4 [Node] et wasm-opt -O4 [Firefox]"
       kind_string )


let make_Ratio_WasmNode_WasmFirefox_plot kind_string =
  make_single_plot Ratio_WasmNode_WasmFirefox
    "Ratio best-Wasm [Node] / best-Wasm [Firefox]"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre best-Wasm \
        [Node] et best-Wasm [Firefox]"
       kind_string )


let make_Ratio_Wasm_X86_plot kind_string =
  make_single_plot Ratio_Wasm_X86 "Ratio best-Wasm [All] / X86-64"
    (Format.sprintf
       "Rapport entre le temps d'exécution sur les versions %s entre best-Wasm \
        [All] et X86-64"
       kind_string )


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


let string_of_sort sort =
  Format.sprintf
    "\\pgfplotstablesort[sort key={%s}]{\\sortedtable}{\\datatable}\n" sort


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


let string_of_axis { number_label; legend } =
  Format.sprintf
    "\\addplot table [x expr=\\coordindex, y=%s] {\\sortedtable};\n\
     \\legend{%s}\n"
    number_label legend


let string_of_axiss axiss =
  axiss |> List.map string_of_axis |> String.concat "\n"


let print_plot ?(force = false) { table; label; sort; axis; max; caption; fig }
    =
  Format.sprintf
    "\\begin{figure}[%s]\n\
    \   \\centering\n\
    \   %s\n\
    \   %s\n\
    \   \\begin{adjustbox}{max width=\\textwidth}\n\
    \      \\begin{tikzpicture}\n\
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
    (string_of_axiss axis) caption fig

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
  |> List.map (fun (_, ((val1, val2), (val3, val4))) ->
    max (max val1 val2) (max val3 val4) )
  |> List.fold_left max 0.
  |> ( *. ) 1.05
  |> round_max


(* Make plots from data *)
let make_times_plot algo values =
  let cpt = ref ~-1 in

  let id_name = "ID" in
  let label_name = "Labels" in
  let val1_name = "CEXE" in
  let val2_name = "JAZZEXE" in
  let val3_name = "CWASM" in
  let val4_name = "JAZZWASM" in

  let first_line =
    [ id_name; label_name; val1_name; val2_name; val3_name; val4_name ]
  in
  let other_lines =
    List.map
      (fun (name, ((val1, val2), (val3, val4))) ->
        incr cpt;
        Format.
          [
            sprintf "%d" !cpt;
            sprintf "{%s}" name;
            sprintf "%f" val1;
            sprintf "%f" val2;
            sprintf "%f" val3;
            sprintf "%f" val4;
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

  let axis = [ val1_name; val2_name; val3_name; val4_name ] in
  let max = compute_round_max_times values in

  let legends = [ "C-->exe"; "C-->Wasm"; "Jazz-->x86-->exe"; "Jazz-->Wasm" ] in
  let caption =
    Format.sprintf
      "Comparaison des temps d'exécution pour %s entre C et Jasmin vers du \
       code natif et vers du code Wasm"
      algo
  in
  let fig = fresh_fig () in

  { table; label; ylabel; precision; sort; axis; legends; max; caption; fig }


let make_times_plot Data_comp_with_c.{ names; values } =
  let lookup_to_microseconds kind =
    Hashtbl.find values kind |> List.map (fun f -> f /. 1000.)
  in

  let times_c_exe = lookup_to_microseconds Data_comp_with_c.Time_C_EXE in
  let times_jazz_exe = lookup_to_microseconds Data_comp_with_c.Time_JAZZ_EXE in
  let times_c_wasm = lookup_to_microseconds Data_comp_with_c.Time_C_WASM in
  let times_jazz_wasm =
    lookup_to_microseconds Data_comp_with_c.Time_JAZZ_WASM
  in

  let times_c = List.combine times_c_exe times_c_wasm in
  let times_jazz = List.combine times_jazz_exe times_jazz_wasm in
  let times = List.combine times_c times_jazz in
  let all = List.combine names times in

  let sha256 = List.take 3 all in
  let all = List.drop 3 all in
  let chacha20 = List.take 3 all in
  let all = List.drop 3 all in
  let chacha20_avx = List.take 3 all in
  let all = List.drop 3 all in
  let chacha20_xor = List.take 3 all in
  let all = List.drop 3 all in
  let chacha20_xor_avx = List.take 3 all in

  [
    make_times_plot "sha256" sha256;
    make_times_plot "chacha20" chacha20;
    make_times_plot "chacha20avx" chacha20_avx;
    make_times_plot "chacha20xor" chacha20_xor;
    make_times_plot "chacha20xoravx" chacha20_xor_avx;
  ]


let make_ratio_plot legends caption Data_comp_with_c.{ names; values } =
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
  let ylabel = "Ratio" in
  let precision = 2 in
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

  { table; label; ylabel; precision; sort; axis; legends; max; caption; fig }


(* Make plots from Node values *)
let make_plot data =
  make_times_plot data
  @ [
      make_ratio_plot
        [ "Ratio C-->exe / Jazz-->x86-->exe"; "Ratio C-->Wasm / Jazz-->Wasm" ]
        "Comparaison avec le ratio des temps d'exécution entre C et Jasmin \
         vers du code natif ainsi que vers du code Wasm"
        data;
    ]


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

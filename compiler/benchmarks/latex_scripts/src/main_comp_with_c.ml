open Data_comp_with_c
open Plot_comp_with_c

(* Compute plots functions *)
let compute_plot lines =
  lines
  |> make_data
  |> make_plot
  |> List.map (print_plot ~force:true)
  |> String.concat "\n\n"
  |> Format.printf "\n\n%s\n\n"


(* Printing functions *)
let print_newpage () = Format.printf "\n\n\n\\newpage\n\n\n%!"

let print_section title = Format.printf "\n\n\\section{%s}\n\n%!" title

let print_subsection subtitle = Format.printf "\n\\subsection{%s}\n%!" subtitle

(* Main *)
let main lines version =
  let c_version =
    match version with
    | "libsodium" -> "librairie Sodium"
    | "libjade" -> "équivalent librairie Jade"
    | _ -> assert false
  in
  print_section
    (Format.sprintf "Comparaison entre C (%s) et Jasmin (librairie Jade)"
       c_version );
  compute_plot lines

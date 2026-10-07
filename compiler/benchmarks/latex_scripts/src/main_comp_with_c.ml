open Data_comp_with_c
open Plot_comp_with_c

(* Compute plots functions *)
let compute_plot lines =
  let plot = print_plot ~force:true (make_plot (make_data lines)) in
  Format.printf "\n\n%s\n\n" plot


(* Printing functions *)
let print_newpage () = Format.printf "\n\n\n\\newpage\n\n\n%!"

let print_section title = Format.printf "\n\n\\section{%s}\n\n%!" title

let print_subsection subtitle = Format.printf "\n\\subsection{%s}\n%!" subtitle

(* Main *)
let main lines =
  print_section
    "Comparaison entre C (librairie Sodium) et Jasmin (librairie Jade)";
  compute_plot lines

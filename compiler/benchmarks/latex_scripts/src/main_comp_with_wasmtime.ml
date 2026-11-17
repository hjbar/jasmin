open Data_comp_with_wasmtime
open Plot_comp_with_wasmtime

(* Compute data functions *)
let compute_data lines =
  let ref_data = make_data Ref lines in
  let opt_data = make_data Opt lines in
  let both_data = make_data Both lines in
  (ref_data, opt_data, both_data)


(* Compute plots functions *)
let compute_plot plot =
  plot |> print_plot ~force:true |> Format.printf "\n\n%s\n\n"


let compute_plots plots =
  plots
  |> List.map (print_plot ~force:true)
  |> String.concat "\n\n"
  |> Format.printf "\n\n%s\n\n"


(* Printing functions *)
let print_newpage () = Format.printf "\n\n\n\\newpage\n\n\n%!"

let print_section title = Format.printf "\n\n\\section{%s}\n\n%!" title

let print_subsection subtitle = Format.printf "\n\\subsection{%s}\n%!" subtitle

(* Main *)
let main lines =
  let ref_data, opt_data, _both_data = compute_data lines in

  print_section
    "Comparaison des temps d'exécutions entre Node+Firefox et Wasmtime";

  print_subsection
    "Comparaison des temps d'exécutions entre Node+Firefox et Wasmtime sur les \
     versions minimales";
  compute_plots (make_times_plot ref_data);

  print_newpage ();

  print_subsection
    "Comparaison des temps d'exécutions entre Node+Firefox et Wasmtime sur les \
     versions optimisées";
  compute_plots (make_times_plot opt_data);

  print_newpage ();

  print_section
    "Comparaison avec le ratio des temps d'éxecution entre Node+Firefox et \
     Wasmtime";

  print_subsection
    "Comparaison avec le ratio des temps d'exécution entre Node+Firefox et \
     Wasmtime sur les versions minimales";
  compute_plot
    (make_ratio_plot
       [ "Ratio Wasmtime / Node+Firefox" ]
       "Comparaison avec le ratio des temps d'exécution entre Node+Firefox et \
        Wasmtime"
       ref_data );

  print_newpage ();

  print_subsection
    "Comparaison avec le ratio des temps d'exécution entre Node+Firefox et \
     Wasmtime sur les versions optimisées";
  compute_plot
    (make_ratio_plot
       [ "Ratio Wasmtime / Node+Firefox" ]
       "Comparaison avec le ratio des temps d'exécution entre Node+Firefox et \
        Wasmtime"
       opt_data )

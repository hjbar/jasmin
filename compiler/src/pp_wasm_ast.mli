open Wasm_ast
open Wasm_headers

val pp_module : Format.formatter -> wasm_headers -> wasm_module -> unit

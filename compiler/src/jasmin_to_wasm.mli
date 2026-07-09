val compile_prog :
  mod_name : Wasm_ast.name ->
  mem_link : Wasm_ast.linkage ->
  mem_env : Wasm_ast.name option ->
  mem_name : Wasm_ast.name ->
  mem_min : Wasm_ast.num ->
  mem_max : Wasm_ast.num option ->
  import_env : Wasm_ast.name ->
  rip_addr : Wasm_ast.num ->
  ('info,
   (Wasm_decl.register, Arch_utils.empty, Arch_utils.empty, Arch_utils.empty, Wasm_decl.condt, Wasm_instr_decl.wasm_op, Arch_utils.empty)
   Arch_extra.extended_op)
  Prog.sprog ->
  Wasm_ast.wasm_module

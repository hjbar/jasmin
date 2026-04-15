val compile_prog :
  mem_env:Wasm_ast.name ->
  mem_name:Wasm_ast.name ->
  mem_min:Wasm_ast.num ->
  import_env:Wasm_ast.name ->
  rip_addr:Wasm_ast.num ->
  init_name:Wasm_ast.funname ->
  ('info,
   (Wasm_decl.register, Arch_utils.empty, Arch_utils.empty, Arch_utils.empty, Wasm_decl.condt, Arch_utils.empty, Arch_utils.empty)
   Arch_extra.extended_op)
  Prog.sfundef list ->
  Expr.sprog_extra ->
  Wasm_ast.wasm_module

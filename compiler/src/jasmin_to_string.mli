val compile_prog :
  rip_addr:Z.t ->
  init_name:string ->
  ('info,
   (Wasm_decl.register, Arch_utils.empty, Arch_utils.empty, Arch_utils.empty, Wasm_decl.condt, Wasm_instr_decl.wasm_op, Arch_utils.empty)
   Arch_extra.extended_op)
  Prog.sfundef list ->
  Expr.sprog_extra ->
  string

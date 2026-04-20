val make_explicit :
  (Expr.stk_fun_extra *
   (int, unit,
    (Wasm_decl.register, Arch_utils.empty, Arch_utils.empty, Arch_utils.empty,
     Wasm_decl.condt, Wasm_instr_decl.wasm_op, Arch_utils.empty)
    Arch_extra.extended_op)
   Prog.gfunc)
  list * Expr.sprog_extra ->
  (Expr.stk_fun_extra *
   (int, unit,
    (Wasm_decl.register, Arch_utils.empty, Arch_utils.empty, Arch_utils.empty,
     Wasm_decl.condt, Wasm_instr_decl.wasm_op, Arch_utils.empty)
    Arch_extra.extended_op)
   Prog.gfunc)
  list * Expr.sprog_extra

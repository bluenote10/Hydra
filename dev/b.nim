import macros
import a

macro remote*(n: untyped): untyped =

  template build(n, additionalProc) {.dirty.} =
    n
    additionalProc

  let additionalProc = buildProcHelper()

  result = getAst(build(n, additionalProc))
  echo result.repr

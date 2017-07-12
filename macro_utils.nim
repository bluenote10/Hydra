import macros

proc getProcName*(n: NimNode): NimNode {.compileTime.} =
  #[
    For public procs the node looks like

        ProcDef
          Postfix
            Ident !"*"
            Ident !"square"

    For private it is:

        ProcDef
          Ident !"square"

  ]#
  case n[0].kind
  of nnkPostFix:
    result = n[0][1]
  else:
    result = n[0]


proc getChildren*(n: NimNode): seq[NimNode] {.compileTime.} =
  result = newSeq[NimNode]()
  for child in n.children:
    result.add(child)
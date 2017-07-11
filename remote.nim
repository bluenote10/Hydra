import macros
import future
import tables


proc getProcName(n: NimNode): NimNode {.compileTime.} =
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


type
  SerializedProc = (string -> string)

var registeredProcs = newTable[int, SerializedProc]()
var procIdLookup = newTable[pointer, int]()
var procId = 0

macro remote*(n: untyped): untyped =
  expectKind n, nnkProcDef

  echo n.treeRepr
  let procName = getProcName(n)

  # This template will add the procs to whatever runtime variable you want,
  # so you can put a table inside here as well :)
  template addRegProc(procDef, procName, procSym) =
    procDef
    bind `procSym`
    echo "Registering proc ", procName, " as ID ", procId, " [addr: ", cast[int](procSym), "]"
    registeredProcs[procId] = procSym
    procIdLookup[cast[pointer](procSym)] = procId
    procId += 1

  result = getAst(addRegProc(n, $procName, ident(procName)))
  echo result.repr

  #result = n

#[
macro checkNode(n: untyped): untyped =
  echo n.kind
  echo n.treerepr

template remote*(n) =
  #echo "registering function: ", n

  discard checkNode(n)
  static:
    registeredProcs &= "a"
    echo registeredProcs
  n
]#

proc square*(x: string): string {.remote.} = "squared"

proc cubic(x: string): string {.remote.} = "cubed"


proc genericCall*(id: int, x: string): string =
  echo "looking up id ", id
  let f = registeredProcs[id]
  result = f(x)

proc genericCall*(f: proc, x: string): string =
  echo "looking up func ", cast[int](f)
  let id = procIdLookup[cast[pointer](f)]
  result = genericCall(id, x)

echo genericCall(0, "")
echo genericCall(1, "")
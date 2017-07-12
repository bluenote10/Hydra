import macros, macro_utils
import future
import tables
import serialization


type
  SerializedProc = (string -> string)

var registeredProcs = newTable[int, SerializedProc]()
var procIdLookup = newTable[pointer, int]()
var procId = 0

macro remote*(n: untyped): untyped =
  expectKind n, nnkProcDef

  # echo n.treeRepr
  let procName = getProcName(n)

  let serializedProcDef = buildSerializedProc(n)
  let serializedProcName = getProcName(serializedProcDef)

  # Template to add procs to registry
  template addRegProc(procDef, serializedProcDef, serializedProcName, serializedProcSym) =
    procDef
    serializedProcDef
    bind `serializedProcSym`
    echo "Registering proc ", serializedProcName, " as ID ", procId, " [addr: ", cast[int](serializedProcSym), "]"
    registeredProcs[procId] = serializedProcSym
    procIdLookup[cast[pointer](serializedProcSym)] = procId
    procId += 1

  result = getAst(addRegProc(
    n,
    serializedProcDef,
    $serializedProcName,
    ident(serializedProcName)
  ))
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

# proc square*(x: float, y: float): int {.remote.} = 1
# proc cubic(x: string): string {.remote.} = "cubed"


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
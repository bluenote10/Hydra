import macros, macro_utils
import future
import tables
import serialization


type
  SerializedProc = (string -> string)

var registeredProcs {.threadvar.}: Table[int, SerializedProc] # = initTable[int, SerializedProc]()
var procIdLookup {.threadvar.}: Table[pointer, int] # = initTable[pointer, int]()
registeredProcs = initTable[int, SerializedProc]()
procIdLookup = initTable[pointer, int]()
var procId = 0

macro remote*(procDef: untyped): untyped =
  expectKind procDef, nnkProcDef

  # echo n.treeRepr
  let origName = $getProcName(procDef)
  let origIdent = ident(origName)

  let sProcDef = buildSerializedProc(procDef)
  let sProcName = $getProcName(sProcDef)
  let sProcIdent = ident(sProcName)

  # Template to add procs to registry
  template addRegProc(procDef, sProcDef, origName, origIdent, sProcIdent) =
    procDef
    sProcDef
    bind `sProcIdent`
    # The lookup memory addr must be the one of orig, because that's what the user will pass in
    echo "Registering proc ", origName, " as ID ", procId, " [addr: ", cast[int](origIdent), "]"
    # The registered proc on the other hand must be the serialized one
    registeredProcs[procId] = sProcIdent
    procIdLookup[cast[pointer](origIdent)] = procId
    procId += 1

  result = getAst(addRegProc(
    procDef,
    sProcDef,
    origName,
    origIdent,
    sProcIdent,
  ))
  echo result.repr
  # echo result.treeRepr


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


proc callById*(id: int, x: string): string =
  echo "looking up id ", id
  let f = registeredProcs[id]
  result = f(x)

proc genericCall*(f: proc, x: string): string =
  echo "looking up func ", cast[int](f)
  let p = cast[pointer](f)
  if procIdLookup.hasKey(p):
    let id = procIdLookup[p]
    result = callById(id, x)
  else:
    raise newException(ValueError, "Can't find passed in proc in remote proc list.")


proc lookupProc*(f: proc): int =
  echo "looking up func ", cast[int](f)
  let p = cast[pointer](f)
  if procIdLookup.hasKey(p):
    let id = procIdLookup[p]
    return id
  else:
    raise newException(ValueError, "Can't find passed in proc in remote proc list.")

# echo genericCall(0, "")
# echo genericCall(1, "")
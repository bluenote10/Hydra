import macros, macro_utils
import future
import typetraits
import tables
import serialization
import anyval
from logger import nil

# -----------------------------------------------------------------------------
# remote proc registration
# -----------------------------------------------------------------------------

type
  ProcId* = int
  SerializedProc = (varargs[AnyVal] -> AnyVal)

var registeredProcs {.threadvar.}: Table[ProcId, SerializedProc] # = initTable[int, SerializedProc]()
var procIdLookup {.threadvar.}: Table[pointer, ProcId] # = initTable[pointer, int]()
registeredProcs = initTable[ProcId, SerializedProc]()
procIdLookup = initTable[pointer, int]()
var procId = ProcId(0)

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
    bind `sProcIdent`, logger.info
    # The lookup memory addr must be the one of orig, because that's what the user will pass in
    logger.info("Registering proc ", origName, " as ID ", procId, " [addr: ", cast[int](origIdent), "]")
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


proc callById*(id: int, args: seq[AnyVal]): AnyVal =
  logger.info "looking up id ", id
  let f = registeredProcs[id]
  result = f(args)

proc genericCall*(f: proc, x: string): string =
  logger.info "looking up func ", cast[int](f)
  let p = cast[pointer](f)
  if procIdLookup.hasKey(p):
    let id = procIdLookup[p]
    result = callById(id, x)
  else:
    raise newException(ValueError, "Can't find passed in proc in remote proc list.")


proc lookupProc*(f: proc): int =
  logger.info "looking up func ", cast[int](f)
  let p = cast[pointer](f)
  if procIdLookup.hasKey(p):
    let id = procIdLookup[p]
    return id
  else:
    raise newException(ValueError, "Can't find passed in proc in remote proc list.")


when false:
  # Examples of macro transformations.

  # Input function annotated with {.remote.}
  proc test(x: float; i: int; data: seq[int]) =
    echo "called with: ", x, ", ", i, ", ", data

  # Currently produces:
  proc testSerialized(args: varargs[string]): string =
    let arg0 = restore(args[0], float)
    let arg1 = restore(args[1], int)
    let arg2 = restore(args[2], seq[int])
    test2(arg0, arg1, arg2)
    result = ""

  []=(registeredProcs, procId, testSerialized)
  []=(procIdLookup, cast[pointer](test), procId)
  procId += 1

  registeredProcs[procId] = testSerialized
  procIdLookup[cast[pointer](test)] = procId

  ## For AnyVal we would need
  proc testNormalized(args: varargs[AnyVal]): AnyVal =
    let arg0 = args[0].to(float)
    let arg1 = args[1].to(int)
    let arg2 = args[2].to(seq[int])
    test2(arg0, arg1, arg2)
    # and for non-void result types something like
    result = toAnyVal(result)

# -----------------------------------------------------------------------------
# remote proc registration
# -----------------------------------------------------------------------------

type
  Serializer*[T] = object
    id: int

  AnySerProc = (AnyVal -> string)
  AnyDeserProc = (string -> AnyVal)

  SerId = int

proc `$`*[T](s: Serializer[T]): string =
  "Serializer[" & name(T) & "]"

proc getId*[T](s: Serializer[T]): int = s.id

proc storeAny[T](s: Serializer[T]): AnySerProc =
  result =
    proc(a: AnyVal): string =
      if not a.ofType(T):
        raise newException(ValueError, "Type of AnyVal does not match to type of serializer")
      let actualValue = a.to(T)
      result = store(actualValue)

proc restoreAny[T](s: Serializer[T]): AnyDeserProc =
  result =
    proc(data: string): AnyVal =
      var actualValue = restore(data, T) # TODO try except
      result = actualValue.toAnyVal


var regSerId = SerId(0)
var regAnySerProc = newTable[SerId, AnySerProc]()
var regAnyDeserProc = newTable[SerId, AnyDeserProc]()
var regSerTypes = newTable[pointer, SerId]()

macro registerSerializer*(T: typedesc): untyped =

  template buildAst(T) =
    bind Serializer, ofType, logger.info
    logger.info("registering serializer for: ", name(T))
    let serializer = Serializer[T](id: regSerId)
    regAnySerProc[regSerId] = storeAny[T](serializer)
    regAnyDeserProc[regSerId] = restoreAny[T](serializer)

    # register type:
    var dummy: T
    let typeAddr = getTypeInfo(dummy)
    regSerTypes[typeAddr] = regSerId

    regSerId += 1
    # serializer

  result = getAst(buildAst(T))
  # echo result.repr

proc lookupSerializerId*(T: typedesc): SerId =
  var dummy: T
  let typeAddr = getTypeInfo(dummy)
  let serId = regSerTypes[typeAddr]
  result = serId

proc lookupDeserializerProc*(serId: int): AnyDeserProc =
  result = regAnyDeserProc[serId]


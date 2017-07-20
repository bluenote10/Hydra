import macros, macro_utils
import future
import typetraits
import tables
import serialization
import anyval

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


proc callById*(id: int, args: seq[AnyVal]): AnyVal =
  echo "looking up id ", id
  let f = registeredProcs[id]
  result = f(args)

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


when false:
  ## Examples of macro transformations.

  ## Input function annotated with {.remote.}
  proc test(x: float; i: int; data: seq[int]) =
    echo "called with: ", x, ", ", i, ", ", data

  ## Currently produces:
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

  ## And in addition serializers/deserializer for all args + output
  proc testSerializedArg0Serializer(x: float) = store(x)
  proc testSerializedArg0Deserializer(s: string) = restore(s, float)
  ## Or should it rather be
  proc testSerializedArg0Serializer(x: AnyVal): string =
    let actualX = x.to(float)
    result = store(x)
  proc testSerializedArg0Deserializer(s: string): AnyVal =
    let actualX = restore(s, float)
    result = actualX.toAnyVal


#[
proc registerSerializer*(T: typedesc) =
  let dummy: T
  let typeInfo = getTypeInfo(dummy)
  let typeAddr = cast[pointer](typeInfo)
]#

type
  Serializer*[T] = object
    id: int
  #Serializer = ref object of RootObj
  #SerializerTyped[T] = ref object of Serializer

  AnySerProc = (AnyVal -> string)
  AnyDeserProc = (string -> AnyVal)

  SerId = int

proc `$`*[T](s: Serializer[T]): string =
  "Serializer[" & name(T) & "]"

proc getId*[T](s: Serializer[T]): int = s.id

#[
proc storeAny[T](s: Serializer[T], a: AnyVal): string =
  if not a.ofType(T):
    raise newException(ValueError, "Type of AnyVal does not match to type of serializer")
  let actualValue = a.to(T)
  result = store(actualValue)

proc restoreAny[T](s: Serializer[T], data: string): AnyVal =
  let actualValue = restore(data, T) # TODO try except
  result = actualValue.toAnyVal
]#

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

macro registerSerializer*(T: typedesc): Serializer[T] =

  template buildAst(T) =
    bind Serializer, ofType
    echo "registering serializer for: ", name(T)
    let serializer = Serializer[T](id: regSerId)
    regAnySerProc[regSerId] = storeAny[T](serializer)
    regAnyDeserProc[regSerId] = restoreAny[T](serializer)
    regSerId += 1
    serializer

  #template enti
  result = getAst(buildAst(T))
  echo result.repr

proc lookupDeserializer*(serId: int): AnyDeserProc =
  regAnyDeserProc[serId]



proc checkTypeAddr*(T: typedesc) =
  var dummy: T
  let p = getTypeInfo(dummy)
  echo name(T), " @ ", cast[int](p)
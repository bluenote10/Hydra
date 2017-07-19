import typeinfo
import typetraits

include "system/inclrtl.nim"
include "system/hti.nim"


type
  AnyVal* = ref object of RootObj
    rawTypePtr: PNimType

  AnyValRef[T] = ref object of AnyVal
    x: T

method getAddr*(a: AnyVal): pointer {.base.} =
  assert false

method getAddr*[T](a: AnyValRef[T]): pointer =
  result = addr(a.x)

method `$`*(a: AnyVal): string {.base.} =
  "AnyVal[base]"

method `$`*[T](a: AnyValRef[T]): string =
  "AnyVal[" & name(T) & "](" & $(a.x) & ")"

template rawType(x: AnyVal): PNimType =
  cast[PNimType](x.rawTypePtr)

template `rawType=`(x: var AnyVal, p: PNimType) =
  x.rawTypePtr = cast[pointer](p)

proc ofType*(a: AnyVal, X: typedesc): bool =
  if a of AnyValRef[X]:
    true
  else:
    false

proc isType(anyval: AnyVal, T: typedesc): bool =
  # Type check based on getTypeInfo() => maybe not needed
  var dummy: T
  let expType = cast[PNimType](getTypeInfo(dummy))
  let gvnType = anyval.rawType
  # echo expType.kind
  # echo gvnType.kind
  # echo repr(expType)
  # echo repr(gvnType)
  # only a necessary condition, not sufficient
  result = expType.kind == gvnType.kind

proc toAnyVal*[T](x: var T): AnyVal =
  AnyValRef[T](rawTypePtr: cast[PNimType](getTypeInfo(x)), x: x)

proc to*(anyval: AnyVal, T: typedesc): T =
  # echo "reconstructing type ", name(T), " of size ", sizeOf(T)
  assert anyVal.ofType(T)
  copyMem(result.addr, anyval.getAddr(), sizeOf(T))


#[
# Alternative type check based on method call
# => deprecated because of "generic method not attachable to object"
method ofType(a: AnyVal, X: typedesc): bool {.base.} =
  assert false

method ofType[T](a: AnyValRef[T], X: typedesc): bool =
  when X is T:
    true
  else:
    false
]#

proc kind*(x: AnyVal): AnyKind =
  result = AnyKind(ord(x.rawType.kind))


when isMainModule:

  template assertNot(x) = assert(not(x))

  block:
    proc constructNested(): AnyVal =
      var s = @[1, 2, 3]
      result = toAnyVal(s)
    for i in 1 .. 100:
      let a = constructNested()
      GC_fullCollect()
      let x = a.to(seq[int])
      assert x == @[1, 2, 3]

  block:
    proc constructNested(): AnyVal =
      var x = 1
      result = toAnyVal(x)

    for i in 1 .. 100:
      let a = constructNested()
      GC_fullCollect()
      assert a.to(int) == 1
      assert a.ofType(int)
      assertNot a.ofType(float)
      assertNot a.ofType(seq[int])

  block:
    type
      Obj = object
        x: int
        y: int

    proc constructNested(): AnyVal =
      var x = Obj(x: 1, y: 2)
      result = toAnyVal(x)

    for i in 1 .. 100:
      let a = constructNested()
      GC_fullCollect()
      assert a.to(Obj) == Obj(x: 1, y: 2)
      assert a.ofType(Obj)
      assertNot a.ofType(int)
      assertNot a.ofType(float)
      assertNot a.ofType(seq[int])

  block:
    type
      Obj = ref object
        x: int
        y: int

    proc constructNested(): AnyVal =
      var x = Obj(x: 1, y: 2)
      result = toAnyVal(x)

    for i in 1 .. 100:
      let a = constructNested()
      GC_fullCollect()
      assert((a.to(Obj)[]) == (Obj(x: 1, y: 2)[]))
      assert a.ofType(Obj)
      assertNot a.ofType(int)
      assertNot a.ofType(float)
      assertNot a.ofType(seq[int])

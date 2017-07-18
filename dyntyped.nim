import typeinfo
import typetraits

include "system/inclrtl.nim"
include "system/hti.nim"

when false:
  type
    AnyVal = ref object of RootObj
      raw: seq[byte]
      rawTypePtr: pointer

    AnyValRef[T] = ref object of AnyVal
      x: T

  template rawType(x: AnyVal): PNimType =
    cast[PNimType](x.rawTypePtr)

  template `rawType=`(x: var AnyVal, p: PNimType) =
    x.rawTypePtr = cast[pointer](p)

  proc toAnyVal[T](x: var T): AnyVal =
    var raw = newSeq[byte](sizeOf(T))
    echo sizeOf(T), raw
    copyMem(raw[0].addr, x.addr, sizeOf(T))
    echo sizeOf(T), raw
    AnyValRef[T](raw: raw, rawTypePtr: nil, x: x) # cast[PNimType](getTypeInfo(x))

  proc to(anyval: AnyVal, T: typedesc): T =
    copyMem(result.addr, unsafeAddr(anyval.raw[0]), sizeOf(T))

  proc kind(x: AnyVal): AnyKind =
    result = AnyKind(ord(x.rawType.kind))


  proc test(): AnyVal =
    var s = @[1, 2, 3]
    result = toAnyVal(s)

  block:
    for i in 1 .. 100:
      let a = test()
      GC_fullCollect()
      let x = a.to(seq[int])
      echo x

type
  AnyVal = ref object of RootObj
    rawTypePtr: PNimType

  AnyValRef[T] = ref object of AnyVal
    x: T

method getAddr*(a: AnyVal): pointer {.base.} =
  assert false

method getAddr*[T](a: AnyValRef[T]): pointer =
  result = addr(a.x)

template rawType(x: AnyVal): PNimType =
  cast[PNimType](x.rawTypePtr)

template `rawType=`(x: var AnyVal, p: PNimType) =
  x.rawTypePtr = cast[pointer](p)

proc toAnyVal*[T](x: var T): AnyVal =
  AnyValRef[T](rawTypePtr: cast[PNimType](getTypeInfo(x)), x: x)

proc to*(anyval: AnyVal, T: typedesc): T =
  echo "reconstructing type ", name(T), " of size ", sizeOf(T)
  copyMem(result.addr, anyval.getAddr(), sizeOf(T))

proc isType(anyval: AnyVal, T: typedesc): bool =
  var dummy: T
  let expType = cast[PNimType](getTypeInfo(dummy))
  let gvnType = anyval.rawType
  # echo expType.kind
  # echo gvnType.kind
  # echo repr(expType)
  # echo repr(gvnType)
  # only a necessary condition, not sufficient
  result = expType.kind == gvnType.kind


#[
method ofType(a: AnyVal, X: typedesc): bool {.base.} =
  assert false

method ofType[T](a: AnyValRef[T], X: typedesc): bool =
  when X is T:
    true
  else:
    false
]#

proc ofType*(a: AnyVal, X: typedesc): bool =
  if a of AnyValRef[X]:
    true
  else:
    false

proc kind*(x: AnyVal): AnyKind =
  result = AnyKind(ord(x.rawType.kind))


when isMainModule:
  proc test(): AnyVal =
    var s = @[1, 2, 3]
    result = toAnyVal(s)

  block:
    for i in 1 .. 100:
      let a = test()
      GC_fullCollect()
      let x = a.to(seq[int])
      echo x

  block:
    var x = 1
    let a = toAnyVal(x)
    echo a.to(int)
    echo a.isType(int)
    echo a.isType(float)
    echo a.isType(seq[int])

    assert a.ofType(int)
    assert(not a.ofType(float))
    assert(not a.ofType(seq[int]))

  block:
    type
      Obj = object
        x: int
        y: int
    var x = Obj(x: 1, y: 2)
    let a = toAnyVal(x)
    echo a.to(Obj)

    echo a.isType(Obj)
    echo a.isType(int)
    echo a.isType(float)
    echo a.isType(seq[int])

  block:
    type
      Obj = ref object
        x: int
        y: int
    var x = Obj(x: 1, y: 2)
    let a = toAnyVal(x)
    echo(a.to(Obj)[])

    echo a.isType(Obj)
    echo a.isType(int)
    echo a.isType(float)
    echo a.isType(seq[int])

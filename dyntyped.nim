import typeinfo

include "system/inclrtl.nim"
include "system/hti.nim"

type
  AnyVal = object
    raw: seq[byte]
    rawTypePtr: pointer

template `rawType=`(x: var AnyVal, p: PNimType) =
  x.rawTypePtr = cast[pointer](p)

proc toAnyVal[T](x: var T): AnyVal =
  var raw = newSeq[byte](sizeOf(T))
  copyMem(raw[0].addr, x.addr, sizeOf(T))
  AnyVal(raw, cast[PNimType](getTypeInfo(x)))

proc kind(x: AnyVal): AnyKind =
  result = AnyKind(ord(x.rawType.kind))
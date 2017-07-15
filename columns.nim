import future
import sequtils
import strutils
import typetraits


type
  Column* = ref object of RootObj

  TypedCol*[T] = ref object of Column
    arr*: seq[T]

method `$`*(c: Column): string {.base.} =
  raise newException(AssertionError, "`$` of base method should not be called.")

method `$`*[T](c: TypedCol[T]): string =
  let typeName = name(T)
  result = "TypedCol[" & typeName & "](" & $c.arr & ")"

method `typeName`*(c: Column): string {.base.} =
  raise newException(AssertionError, "`typeName` of base method should not be called.")

method `typeName`*[T](c: TypedCol[T]): string =
  result = name(T)

proc newCol*[T](s: seq[T]): Column =
  return TypedCol[T](arr: s)

proc newCol*[T](length: int): Column =
  return TypedCol[T](newSeq[T](length))


template assertType(c: Column, T: typedesc): TypedCol[T] =
  if not (c of TypedCol[T]):
    let pos = instantiationInfo()
    let msg = "Expected column of type [$1], got [$2] at $3:$4" % [
      name(T),
      c.typeName(),
      pos.filename,
      $pos.line,
    ]
    echo msg
    raise newException(ValueError, msg)
  cast[TypedCol[T]](c)

template toTyped(newCol: untyped, c: Column, T: typedesc): untyped =
  if not (c of TypedCol[T]):
    raise newException(ValueError, "Expected column of type " & name(T))
  let newCol = cast[TypedCol[T]](c)


when isMainModule:
  proc genDynamicCol(s: string): Column =
    case s
    of "string":
      return newCol(@["1", "2", "3"])
    of "int":
      return newCol(@[1, 2, 3])

  proc operateOnCol(c: Column) =
    if c of TypedCol[string]:
      let cTyped = cast[TypedCol[string]](c)
      echo "string column": cTyped.arr
    elif c of TypedCol[int]:
      let cTyped = cast[TypedCol[int]](c)
      echo "int column": cTyped.arr
    else:
      echo "can't match type"

  let c1 = genDynamicCol("string")
  let c2 = genDynamicCol("int")

  echo c1
  echo c2
  operateOnCol(c1)
  operateOnCol(c2)

  block:
    let c1 = c1.assertType(string)
    let c2 = c2.assertType(int)
    echo c1.arr
    echo c2.arr

  block:
    toTyped(c1, c1, string)
    toTyped(c2, c2, int)
    echo c1.arr
    echo c2.arr
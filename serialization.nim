import macros, macro_utils
import typeinfo
import streams
import typeinfo


proc serialize*[T: SomeInteger|SomeReal](s: Stream, x: T) =
  s.write(x)

proc serialize*(s: Stream, x: string) =
  # For short strings storing an 8 byte length is
  # quite an overhead. Could be optimized.
  s.write(x.len)
  s.write(x)


proc serialize*[T](s: Stream, x: seq[T]) =
  s.write(x.len)
  # TODO we need to differentiate between native / fixed-width types
  var tmp: seq[T]
  shallowCopy(tmp, x)
  s.writeData(addr(tmp[0]), sizeof(T) * x.len)
  # General solution would require
  # for i in 0 ..< x.len:
  #   s.serialize(x[i])

proc serialize*[N, T](s: Stream, x: array[N, T]) =
  s.write(x.len)
  # TODO we need to differentiate between native / fixed-width types
  var tmp: array[N, T]
  shallowCopy(tmp, x)
  s.writeData(addr(tmp[0]), sizeof(T) * x.len)
  # General solution would require
  # for i in 0 ..< x.len:
  #   s.serialize(x[i])

#[
# Attempt to merge seq+array versions into openarray seems to be tricky here
#
proc serialize*[T](s: Stream, x: openarray[T]) =
  s.write(x.len)
  # TODO we need to differentiate between native / fixed-width types
  when x is seq:
    var tmp: seq[T]
    shallowCopy(tmp, x)
    s.writeData(addr(tmp[0]), sizeof(T) * x.len)
  else:
    var tmp: array[1, T]
    shallowCopy(tmp, cast[array[1, T]](x))
    s.writeData(addr(tmp[0]), sizeof(T) * x.len)
  # General solution would require
  # for i in 0 ..< x.len:
  #   s.serialize(x[i])
]#


proc newEIO(msg: string): ref IOError =
  new(result)
  result.msg = msg

proc read[T](s: Stream, result: var T) =
  ## generic read procedure. Reads `result` from the stream `s`.
  if readData(s, addr(result), sizeof(T)) != sizeof(T):
    raise newEIO("cannot read from stream")

#[
proc deser*[T: SomeInteger|SomeReal](s: Stream): T =
  read[T](s, result)

proc deser*[T: string](s: Stream): string =
  var len: int
  read[int](s, len)
  result = s.readStr(len)


proc deser*[T](s: Stream): seq[T] =
  var len: int
  read[int](s, len)
  result.setlen(len)
  if readData(s, addr(result[0]), sizeof(T) * len) != sizeof(T) * len:
    raise newEIO("cannot read from stream")
]#

proc deserialize*(s: Stream, T: typedesc[SomeInteger|SomeReal]): T =
  read[T](s, result)

proc deserialize*(s: Stream, T: typedesc[string]): string =
  var len: int
  read[int](s, len)
  result = s.readStr(len)

proc deserialize*[U](s: Stream, T: typedesc[seq[U]]): seq[U] =
  var len: int
  read[int](s, len)
  echo len
  result = newSeq[U](len)
  if readData(s, addr(result[0]), sizeof(U) * len) != sizeof(U) * len:
    raise newEIO("cannot read from stream")

proc deserialize*[N, U](s: Stream, T: typedesc[array[N, U]]): array[N, U] =
  var len: int
  read[int](s, len)
  assert len == result.len
  if readData(s, addr(result[0]), sizeof(U) * len) != sizeof(U) * len:
    raise newEIO("cannot read from stream")

# -----------------------------------------------------------------------------
# High level API (string)
# -----------------------------------------------------------------------------

proc store*[T](x: T): string =
  let stream = newStringStream()
  stream.serialize(x)
  result = stream.data

proc restore*(s: string, T: typedesc): T =
  let stream = newStringStream(s)
  result = stream.deserialize(T)


# -----------------------------------------------------------------------------
# Serialization companion proc generation
# -----------------------------------------------------------------------------

proc buildSerializedProc*(n: NimNode): NimNode {.compileTime.} =
  # echo n.treeRepr
  let origProcName = getProcName(n)

  let formalParams = n[3]
  let args = formalParams.getChildren[1..<formalParams.len]
  # let returnNode = formalParams[0]
  # echo returnNode.treeRepr
  # echo args.repr

  var argStatements = newStmtList()
  var origProcCall = newCall(ident(origProcName))

  template defineArg(argName, argType) {.dirty.} =
    # Note: it's important to bind deserialize here where it is actually
    # used and not in the context of the other template (where `bind`
    # would not work for deserialize). Rule of thumb: bind in usage scope
    bind deserialize
    let argName = inStream.deserialize(argType)

  for i, arg in args.pairs:
    let argName = ident("arg" & $i)
    let argType = arg[1]
    argStatements.add(getAst(defineArg(argName, argType)))
    origProcCall.add(argName)

  # echo argStatements.repr

  template buildProc(procName, argStatements, origProc, origProcCall) {.dirty.} =
    proc procName(s: string): string =
      bind procName, newStringStream, serialize
      var inStream = newStringStream(s)
      argStatements
      let origRes = origProcCall
      var outStream = newStringStream()
      outStream.serialize(origRes)
      result = outStream.data

  result = getAst(buildProc(
    ident($origProcName & "Serialized"),
    argStatements,
    ident($origProcName),
    origProcCall
  ))
  # getAst gives a StmtList with the first statement being the proc def
  result = result[0]
  # echo result.repr
  # echo result.treeRepr


# -----------------------------------------------------------------------------
# Quick checks
# -----------------------------------------------------------------------------

when isMainModule:
  var s = newStringStream()

  s.serialize(42)
  s.serialize(1.0)
  s.serialize("hey")
  s.serialize(@[1,2,3])
  s.serialize([1,2,3])

  echo s.data

  for c in s.data:
    echo ord(c)

  echo "------------------"
  s.setPosition(0)
  #echo deserialize[int](s)
  #echo deserialize[float](s)
  #echo deserialize[string](s)
  #echo deserialize[seq[int]](s)

  echo s.deserialize(int)
  echo s.deserialize(float)
  echo s.deserialize(string)
  echo s.deserialize(seq[int])
  echo @(s.deserialize(array[3, int])) # lack of $ for array

  import times
  template runTimed(body: untyped) =
    let t1 = epochTime()
    body
    let t2 = epochTime()
    echo t2 - t1


  block:
    echo "Serializing"
    runTimed:
      let huge = newSeq[int](8_000_000)
      var fs = newFileStream("/media/GamesII/nim_serialization_test.dat", fmWrite)
      fs.serialize(huge)
      fs.close()

  block:
    echo "Deserializing"
    runTimed:
      var fs = newFileStream("/media/GamesII/nim_serialization_test.dat", fmRead)
      let huge = fs.deserialize(seq[int])
      echo huge.len

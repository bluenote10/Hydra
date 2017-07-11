import macros
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


#[
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


proc newEIO(msg: string): ref IOError =
  new(result)
  result.msg = msg

proc read[T](s: Stream, result: var T) =
  ## generic read procedure. Reads `result` from the stream `s`.
  if readData(s, addr(result), sizeof(T)) != sizeof(T):
    raise newEIO("cannot read from stream")


proc deser*[T: SomeInteger|SomeReal](s: Stream): T =
  read[T](s, result)

proc deser*[T: string](s: Stream): string =
  var len: int
  read[int](s, len)
  result = s.readStr(len)

#[
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

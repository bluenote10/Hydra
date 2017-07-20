import asyncdispatch

import runner
import driver
import remote
import serialization

let floatSerializer = registerSerializer(float)
let intSerializer = registerSerializer(int)
let intSeqSerializer = registerSerializer(seq[int])

checkTypeAddr(float)
checkTypeAddr(int)
checkTypeAddr(seq[int])
checkTypeAddr(seq[float])


proc helloWorldProcNonRemote() =
  echo "hello world from non-remote"

proc helloWorldProc(i: int) {.remote.} =
  echo "hello world from abroad"
  helloWorldProcNonRemote()

proc test2(x: float, i: int, data: seq[int]) {.remote.} =
  echo "called with: ", x, ", ", i, ", ", data


launcher do (ctx: Context):
  checkTypeAddr(float)
  checkTypeAddr(int)
  checkTypeAddr(seq[int])
  checkTypeAddr(seq[float])

  waitFor ctx.registerData("i", 42, intSerializer)
  waitFor ctx.registerData("x", 0.5, floatSerializer)
  waitFor ctx.registerData("data", @[1, 2, 3], intSeqSerializer)
  #waitFor ctx.registerDataSerialized("i", store(42))
  #waitFor ctx.registerDataSerialized("x", store(0.5))
  #waitFor ctx.registerDataSerialized("data", store(@[1, 2, 3]))
  #waitFor ctx.remoteCall(helloWorldProc, @["i"])
  waitFor ctx.remoteCall(test2, @["x", "i", "data"])
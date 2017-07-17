import asyncdispatch

import runner
import driver
import remote
import serialization


proc helloWorldProcNonRemote() =
  echo "hello world from non-remote"

proc helloWorldProc(i: int) {.remote.} =
  echo "hello world from abroad"
  helloWorldProcNonRemote()

proc test2(x: float, i: int, data: seq[int]) {.remote.} =
  echo "called with: ", x, ", ", i, ", ", data


launcher do (ctx: Context):
  waitFor ctx.registerData("i", store(42))
  waitFor ctx.registerData("x", store(0.5))
  waitFor ctx.registerData("data", store(@[1, 2, 3]))
  waitFor ctx.remoteCall(helloWorldProc, @["i"])
  waitFor ctx.remoteCall(test2, @["x", "i", "data"])
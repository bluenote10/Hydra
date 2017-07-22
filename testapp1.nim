import asyncdispatch

import runner
import driver
import remote

registerSerializer(float)
registerSerializer(int)
registerSerializer(seq[int])

proc remoteHelloWorld(x: float, i: int, data: seq[int]) {.remote.} =
  echo "I'm running on a worker"
  echo x
  echo i
  echo data

launcher do (ctx: Context):
  waitFor ctx.registerData("i", 42)
  waitFor ctx.registerData("x", 0.5)
  waitFor ctx.registerData("data", @[1, 2, 3])

  waitFor ctx.remoteCall(remoteHelloWorld, @["x", "i", "data"])

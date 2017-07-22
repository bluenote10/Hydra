import asyncdispatch
import math

import runner
import driver
import remote

registerSerializer(float)
registerSerializer(int)
registerSerializer(seq[int])

proc remoteHelloWorld(i: int, data: seq[int]): float {.remote.} =
  echo "I'm running on a worker"
  echo i
  echo data
  result = sum(data).float

launcher do (ctx: Context):
  waitFor ctx.pushData("i", 42)
  waitFor ctx.pushData("x", 0.5)
  waitFor ctx.pushData("data", @[1, 2, 3])

  waitFor ctx.remoteCall(remoteHelloWorld, @["x", "i", "data"], "result")

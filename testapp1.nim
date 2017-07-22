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


proc remoteApp(ctx: Context) =
  ctx.pushData("i", 42)
  ctx.pushData("x", 0.5)
  ctx.pushData("data", @[1, 2, 3])

  ctx.remoteCall(remoteHelloWorld, @["i", "data"], "result")

  let result = ctx.pullData("result", float)
  echo result


launch(remoteApp)

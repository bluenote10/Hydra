import runner
import driver
import remote
import asyncdispatch

proc helloWorldProc1() =
  echo "hello world from abroad"

proc helloWorldProc(): int {.remote.} =
  echo "hello world from abroad"


# proc

launcher do (ctx: Context):
  echo "hello world"
  waitFor ctx.remoteCall(helloWorldProc)
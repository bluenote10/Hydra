import runner
import driver
import remote
import asyncdispatch

proc helloWorldProcNonRemote() =
  echo "hello world from non-remote"

proc helloWorldProc() {.remote.} =
  echo "hello world from abroad"
  helloWorldProcNonRemote()


# proc

launcher do (ctx: Context):
  echo "hello world"
  waitFor ctx.remoteCall(helloWorldProc)
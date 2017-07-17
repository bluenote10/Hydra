import future
import asyncnet, asyncdispatch
import remote
import net_utils
import messages


type
  Context* = ref object
    master: AsyncSocket
    workers: seq[AsyncSocket]

  ClientApp* = Context -> void


proc registerData*(ctx: Context, key: string, dataSerialized: string) {.async.} =
  await ctx.master.sendMsg(msgRegisterData(key, dataSerialized))


proc remoteCall*(ctx: Context, f: proc, args: seq[string]) {.async.} =
  let procId = lookupProc(f)
  await ctx.master.sendMsg(msgRemoteCall(procId, args))


proc driverMain(clientApp: ClientApp) {.async.} =
  echo "Trying to connect to master"
  var master = newAsyncSocket()
  await master.connectRetrying("localhost", Port(12345))
  await master.sendMsg(msgRegisterDriver())

  let ctx = Context(
    master: master,
    workers: newSeq[AsyncSocket](),
  )

  clientApp(ctx)


proc runDriver*(clientApp: ClientApp) =
  waitFor driverMain(clientApp)

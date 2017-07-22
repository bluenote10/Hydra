import future
import asyncnet, asyncdispatch
import remote
import serialization
import net_utils
import messages
from logger import nil

type
  Context* = ref object
    master: AsyncSocket
    workers: seq[AsyncSocket]

  ClientApp* = Context -> void


proc registerData*[T](ctx: Context, key: string, x: T, serializer: Serializer[T]) {.async.} =
  let dataSerialized = store(x)
  let serId = serializer.getId()
  await ctx.master.sendMsg(msgRegisterData(key, dataSerialized, serId))

proc registerData*[T](ctx: Context, key: string, x: T) {.async.} =
  let dataSerialized = store(x)
  let serId = lookupSerializerId(T)
  await ctx.master.sendMsg(msgRegisterData(key, dataSerialized, serId))


proc remoteCall*(ctx: Context, f: proc, args: seq[string]) {.async.} =
  let procId = lookupProc(f)
  await ctx.master.sendMsg(msgRemoteCall(procId, args))


proc driverMain(clientApp: ClientApp) {.async.} =
  logger.info("Trying to connect to master")
  var master = newAsyncSocket()
  await master.connectRetrying("localhost", Port(12345))
  await master.sendMsg(msgRegisterDriver())

  # Worker connection just for testing purposes. Eventually
  # worker connections should probably handled on-demand, i.e.,
  # the worker will communicate "push data to worker XXX" or
  # pull data from worker XXX" and the driver will have to
  # maintain a connection pool. If a worker is not in the
  # table of connections, the driver would either have to
  # make a IP-address lookup request on the master, or the
  # master includes the (immutable) connection details whenever
  # it communicates the worker ID.
  var worker = newAsyncSocket()
  await worker.connectRetrying("localhost", Port(12346))

  let ctx = Context(
    master: master,
    workers: newSeq[AsyncSocket](),
  )

  clientApp(ctx)


proc runDriver*(clientApp: ClientApp) =
  waitFor driverMain(clientApp)

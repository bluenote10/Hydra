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


proc pushData*[T](ctx: Context, key: string, x: T, serializer: Serializer[T]) =
  let dataSerialized = store(x)
  let serId = serializer.getId()
  waitFor ctx.master.sendMsg(msgPushData(key, dataSerialized, serId))

proc pushData*[T](ctx: Context, key: string, x: T) =
  let dataSerialized = store(x)
  let serId = lookupSerializerId(T)
  waitFor ctx.master.sendMsg(msgPushData(key, dataSerialized, serId))

proc pullData*(ctx: Context, key: string, T: typedesc): T =
  let serId = lookupSerializerId(T)
  waitFor ctx.master.sendMsg(msgPullData(key, serId))
  let msg = waitFor ctx.workers[0].receiveMsg(Message)
  case msg.kind
  of MsgKind.PureData:
    result = msg.pureData.restore(T)
  else:
    logger.warn("Received message: ", msg, " but expected PureData.")


proc remoteCall*(ctx: Context, f: proc, args: seq[string], resultKey: string) =
  ## TODO should we check that the number of args matches?
  let procId = lookupProc(f)
  waitFor ctx.master.sendMsg(msgRemoteCall(procId, args, resultKey))


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
    workers: @[worker],
  )

  clientApp(ctx)


proc runDriver*(clientApp: ClientApp) =
  waitFor driverMain(clientApp)

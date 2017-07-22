import asyncnet, asyncdispatch
import marshal
import future
import net_utils
import messages
from logger import nil


type
  Master = ref object
    driver: AsyncSocket
    workers: seq[AsyncSocket]



proc handleDriver(master: Master, driver: AsyncSocket) {.async.} =

  while true:

    let msg = await driver.receiveMsg(Message)
    if driver.isClosed(): break

    case msg.kind
    of MsgKind.PushData:
      logger.info("received request to register data: ", msg.keyPush)
      # => forward message to worker -- TODO: proper scheduling
      if master.workers.len > 0:
        await master.workers[0].sendMsg(msg)
      # In the next iteration we would not forward the key+data here
      # but rather make it two steps: The client request a push of
      # a key, and we communicate back a worker ID to which the
      # key+value should be send.
    of MsgKind.PullData:
      logger.info("received request to pull data: ", msg.keyPull)
      # => forward message to worker -- TODO: proper scheduling
      if master.workers.len > 0:
        await master.workers[0].sendMsg(msg)
    of MsgKind.RemoteCall:
      logger.info("received request to call remote proc: ", msg.procId)
      # => forward message to worker -- TODO: proper scheduling
      if master.workers.len > 0:
        await master.workers[0].sendMsg(msg)
    else:
      logger.info("Received illegal welcome message: " & $msg)

  logger.info("Driver disconnected")

proc handleWorker(master: Master, worker: AsyncSocket) {.async.} =

  while true:

    let msg = await worker.receiveMsg(Message)
    if worker.isClosed(): break

  logger.info("Worker disconnected")


proc msgLoop(master: Master) {.async.} =

  while true:
    # echo "master main loop. connected workers: ", master.workers.len, " connected driver ", (not master.driver.isNil)
    await sleepAsync(2000)


proc listen() {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(12345))
  server.listen()

  var master = Master(driver: nil, workers: newSeq[AsyncSocket]())

  asyncCheck master.msgLoop()

  while true:
    logger.info("Waiting for client connections")
    let newClient = await server.accept()

    var msg = await newClient.receiveMsg(Message)

    case msg.kind
    of MsgKind.RegisterDriver:
      showConnectionDetails(newClient, "driver")
      if master.driver.isNil():
        master.driver = newClient
      else:
        logger.info("ERROR: Refused driver registration. Driver already connected.")
      asyncCheck master.handleDriver(newClient)
    of MsgKind.RegisterWorker:
      showConnectionDetails(newClient, "worker")
      master.workers.add(newClient)
      asyncCheck master.handleWorker(newClient)
    else:
      logger.info("Received illegal welcome message: " & $msg)


proc runMaster*() =
  logger.info("Running master")
  asyncCheck listen()
  runForever()
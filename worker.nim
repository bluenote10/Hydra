import asyncnet, asyncdispatch
import marshal
import future
import tables

import net_utils
import messages

import remote
import anyval
from logger import nil

type
  Worker = ref object
    driver: AsyncSocket
    master: AsyncSocket
    workers: seq[AsyncSocket]
    kvStore: TableRef[string, AnyVal] not nil


proc handleMaster(worker: Worker) {.async.} =
  let master = worker.master

  while true:

    let msg = await master.receiveMsg(Message)
    if master.isClosed(): break

    case msg.kind
    of MsgKind.PushData:
      let key = msg.keyPush
      logger.info("Received request to register data: ", key)
      let serId = msg.serializerIdPush
      logger.info("Trying to lookup deserializer with id: ", serId)
      let deserProc = lookupDeserializerProc(serId)
      let anyval = deserProc(msg.data)
      logger.info(anyval)
      worker.kvStore[key] = anyval
    of MsgKind.PullData:
      let key = msg.keyPull
      logger.info("Received request to register data: ", key)
      let serId = msg.serializerIdPull
      logger.info("Trying to lookup deserializer with id: ", serId)
      let serProc = lookupSerializerProc(serId)
      let rawData = serProc(worker.kvStore[key])
      await worker.driver.sendMsg(msgPureData(rawData))
    of MsgKind.RemoteCall:
      logger.info("Received request to call remote proc: ", msg.procId)
      var args = newSeq[AnyVal](msg.args.len)
      for i in 0 ..< msg.args.len:
        let key = msg.args[i]
        args[i] = worker.kvStore[key] # TODO handle missing keys...
      let anyResult = callById(msg.procId, args)
      worker.kvStore[msg.resultKey] = anyResult
    else:
      logger.info("Received illegal welcome message: " & $msg)

  logger.info("Master disconnected")


proc handleDriver(worker: Worker) {.async.} =
  let driver = worker.driver

  while true:

    let msg = await driver.receiveMsg(Message)
    if driver.isClosed(): break

  logger.info("Driver disconnected")


proc listen() {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(12346))
  server.listen()

  let worker = Worker(
    workers: newSeq[AsyncSocket](),
    kvStore: newTable[string, AnyVal](),
  )

  # connect to master
  while true:
    logger.info("Trying to connect to master")
    var master = newAsyncSocket()
    await master.connectRetrying("localhost", Port(12345))
    await master.sendMsg(msgRegisterWorker())

    worker.master = master
    asyncCheck worker.handleMaster()

    while true:
      logger.info("Waiting for driver connection")
      let driver = await server.accept()
      logger.info("Received driver connect from: ", $driver)
      worker.driver = driver
      await worker.handleDriver()


proc runWorker*() =
  logger.info("Running worker")
  asyncCheck listen()
  runForever()
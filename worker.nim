import asyncnet, asyncdispatch
import marshal
import future
import tables

import net_utils
import messages

import remote
import anyval


type
  Worker = ref object
    driver: AsyncSocket
    master: AsyncSocket
    workers: seq[AsyncSocket]
    kvStore: TableRef[string, string] not nil
    kvStore2: TableRef[string, AnyVal] not nil


proc handleMaster(worker: Worker) {.async.} =
  let master = worker.master

  while true:

    let msg = await master.receiveMsg(Message)
    if master.isClosed(): break

    case msg.kind
    of MsgKind.RegisterData:
      echo "received request to register data: ", msg.key
      worker.kvStore[msg.key] = msg.data
      let serId = msg.serializerId
      echo "trying to lookup deserializer with id: ", serId
      let deser = lookupDeserializer(serId)
      let anyval = deser(msg.data)
      echo anyval
      worker.kvStore2[msg.key] = anyval
    of MsgKind.RemoteCall:
      echo "received request to call remote proc: ", msg.procId
      var args = newSeq[AnyVal](msg.args.len)
      for i in 0 ..< msg.args.len:
        let key = msg.args[i]
        args[i] = worker.kvStore2[key] # TODO handle missing keys...
      echo callById(msg.procId, args)
    else:
      echo "Received illegal welcome message: " & $msg

  echo "Master disconnected"


proc handleDriver(worker: Worker) {.async.} =
  let driver = worker.driver

  while true:

    let msg = await driver.receiveMsg(Message)
    if driver.isClosed(): break

  echo "Driver disconnected"


proc listen() {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(12346))
  server.listen()

  let worker = Worker(
    workers: newSeq[AsyncSocket](),
    kvStore: newTable[string, string](),
    kvStore2: newTable[string, AnyVal](),
  )

  # connect to master
  while true:
    echo "Trying to connect to master"
    var master = newAsyncSocket()
    await master.connectRetrying("localhost", Port(12345))
    await master.sendMsg(msgRegisterWorker())

    worker.master = master
    asyncCheck worker.handleMaster()

    while true:
      echo "Waiting for driver connection"
      let driver = await server.accept()
      echo "Received driver connect from: ", $driver
      worker.driver = driver
      await worker.handleDriver()


proc runWorker*() =
  echo "Running worker"
  asyncCheck listen()
  runForever()
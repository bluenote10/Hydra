import asyncnet, asyncdispatch
import marshal
import future
import net_utils
import messages

import remote


type
  Worker = ref object
    driver: AsyncSocket
    master: AsyncSocket
    workers: seq[AsyncSocket]


proc handleMaster(worker: Worker) {.async.} =
  let master = worker.master

  while true:

    let msg = await master.receiveMsg(Message)
    case msg.kind
    of MsgKind.RemoteCall:
      echo "received request to call remote proc: ", msg.procId
      echo callById(msg.procId, "")
    else:
      echo "Received illegal welcome message: " & $msg


proc handleDriver(worker: Worker) {.async.} =
  let driver = worker.driver

  while true:

    let msg = await driver.receiveMsg(string)


proc listen() {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(12346))
  server.listen()

  let worker = Worker(workers: newSeq[AsyncSocket]())

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
      worker.driver = driver
      await worker.handleDriver()


proc runWorker*() =
  echo "Running worker"
  asyncCheck listen()
  runForever()
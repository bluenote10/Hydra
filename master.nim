import asyncnet, asyncdispatch
import marshal
import future
import net_utils
import messages


type
  Master = ref object
    driver: AsyncSocket
    workers: seq[AsyncSocket]



proc handleDriver(master: Master, driver: AsyncSocket) {.async.} =

  while true:

    let msg = await driver.receiveMsg(Message)
    case msg.kind
    of MsgKind.RemoteCall:
      echo "received request to call remote proc: ", msg.procId
      if master.workers.len > 0:
        await master.workers[0].sendMsg(msg)
    else:
      echo "Received illegal welcome message: " & $msg


proc handleWorker(master: Master, worker: AsyncSocket) {.async.} =

  while true:

    let msg = await worker.receiveMsg(Message)


proc msgLoop(master: Master) {.async.} =

  while true:
    echo "master main loop. connected workers: ", master.workers.len, " connected driver ", (not master.driver.isNil)
    await sleepAsync(1000)


proc listen() {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(12345))
  server.listen()

  var master = Master(driver: nil, workers: newSeq[AsyncSocket]())

  asyncCheck master.msgLoop()

  while true:
    echo "Waiting for client connections"
    let newClient = await server.accept()

    var msg = await newClient.receiveMsg(Message)

    case msg.kind
    of MsgKind.RegisterDriver:
      showConnectionDetails(newClient, "driver")
      if master.driver.isNil():
        master.driver = newClient
      else:
        echo "ERROR: Refused driver registration. Driver already connected."
      asyncCheck master.handleDriver(newClient)
    of MsgKind.RegisterWorker:
      showConnectionDetails(newClient, "worker")
      master.workers.add(newClient)
      asyncCheck master.handleWorker(newClient)
    else:
      echo "Received illegal welcome message: " & $msg


proc runMaster*() =
  echo "Running master"
  asyncCheck listen()
  runForever()
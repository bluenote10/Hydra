import asyncnet, asyncdispatch
import marshal
import future
import net_utils


proc handleDriver(driver: AsyncSocket, master: AsyncSocket) {.async.} =

  while true:

    let msg = await driver.receiveMsg(string)


proc listen() {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(12346))
  server.listen()

  # connect to master
  while true:
    echo "Trying to connect to master"
    var master = newAsyncSocket()
    echo "is closed after init: ", master.isClosed()
    await master.connect("localhost", Port(12345))
    await master.sendMsg("worker")

    while true:
      echo "Waiting for driver connection"
      let client = await server.accept()
      await handleDriver(client, master)


proc runWorker*() =
  echo "Running worker"
  asyncCheck listen()
  runForever()
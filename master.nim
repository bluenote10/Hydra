import asyncnet, asyncdispatch
import marshal
import future
import net_utils


proc handleDriver(client: AsyncSocket) {.async.} =

  while true:

    var msgSize = 0

    let numRead = await client.recvInto(msgSize.addr, sizeOf(int))
    if numRead != sizeOf(int):
      break


proc handleWorker(client: AsyncSocket) {.async.} =

  while true:

    var msgSize = 0

    let numRead = await client.recvInto(msgSize.addr, sizeOf(int))
    if numRead != sizeOf(int):
      break


proc listen() {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(12345))
  server.listen()

  while true:
    echo "Waiting for client connections"
    let client = await server.accept()

    var clientType = await client.receiveMsg(string)

    if clientType == "driver":
      showConnectionDetails(client, "driver")
      asyncCheck handleDriver(client)
    else:
      showConnectionDetails(client, "worker")
      asyncCheck handleWorker(client)


proc runMaster*() =
  echo "Running master"
  asyncCheck listen()
  runForever()
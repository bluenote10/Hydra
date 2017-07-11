import asyncnet, asyncdispatch
import marshal
import future

type fptr = (proc(x: float): float)

import driver

proc processClient(client: AsyncSocket) {.async.} =

  while true:

    var msgSize = 0

    let numRead = await client.recvInto(msgSize.addr, sizeOf(int))
    if numRead != sizeOf(int):
      break

    echo "trying to receive message of size ", msgSize
    let msg = await client.recv(msgSize)

    echo "received: ", msg

    var data = to[(pointer, int)](msg)
    echo "data: ", data

    var p = data[0]
    echo cast[int](p)
    #var f = cast[globalSquare](p)
    let arg = data[1]
    #echo f, arg

    if len(msg) == 0:
      break


proc serve() {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(12345))
  server.listen()

  while true:
    let client = await server.accept()
    asyncCheck processClient(client)


proc runWorker*() =
  echo "running worker"
  asyncCheck serve()
  runForever()
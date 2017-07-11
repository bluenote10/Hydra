import asyncnet, asyncdispatch
import marshal
import remote

proc globalSquare*(x: float): float {.remote.} = x * x

proc checkAddress() =

  proc square(x: float): float {.closure.} = x * x
  let p = square.rawProc
  echo cast[int](p)

  #var f = square
  #echo cast[int](f)

  let pGlobal = globalSquare
  echo cast[int](pGlobal)

#checkAddress()


proc squareWrapped(msg: string): string =
  let x = to[int](msg)
  let y = x * x
  result = $$y


proc sendMsg*(socket: AsyncSocket, msg: string) {.async.} =
  var msgSize = msg.len.int
  await socket.send(msgSize.addr, sizeOf(int))
  await socket.send(msg)

proc sendMsg*[T](socket: AsyncSocket, x: T) {.async.} =
  var msg = $$x
  var msgSize = msg.len.int
  await socket.send(msgSize.addr, sizeOf(int))
  await socket.send(msg)


proc main() {.async.} =
  var client = newAsyncSocket()
  await client.connect("localhost", Port(12345))

  #await client.send("Hello world\c\L")
  #await client.sendMsg("Hello world")
  let msg = (globalSquare, 42)
  await client.sendMsg(msg)

  #let response = await client.recvLine()
  #echo "Received: " & response & "!"


proc runDriver*() =
  waitFor main()

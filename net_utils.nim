import asyncnet, asyncdispatch
import nativesockets
import marshal
import strutils
import messages


proc connectRetrying*(socket: AsyncSocket, url: string, port: Port) {.async.} =
  var connected = false
  while not connected:
    echo "Trying to connect to $1:$2" % [url, $port]
    let fut = socket.connect(url, port)
    yield fut
    if not fut.failed:
      connected = true
    else:
      await sleepAsync(1000)


proc sendMsg*[T](socket: AsyncSocket, x: T) {.async.} =
  var msg = $$x
  var msgSize = msg.len.int
  echo "sending msgSize = ", msgSize
  await socket.send(msgSize.addr, sizeOf(int))
  echo "sending msg = ", msg
  await socket.send(msg)


proc receiveMsg*(socket: AsyncSocket, T: typedesc): Future[T] {.async.} =
  var msgSize: int

  echo "trying to read size of message"
  let numRead = await socket.recvInto(msgSize.addr, sizeOf(int))
  echo numRead
  if numRead != sizeOf(int):
    raise newException(IOError, "Could not read expected number of bytes from socket.")

  echo "trying to receive message of size ", msgSize
  let rawMsg = await socket.recv(msgSize)

  echo "trying to parse rawMsg: ", rawMsg
  result = to[T](rawMsg)


proc showConnectionDetails*(socket: AsyncSocket, clientName: string) =
  let socketHandle = socket.getFd()
  let (address, port) = socketHandle.getPeerAddr(socketHandle.getSockDomain())
  echo "Received connection from $1:$2 ($3)" % [address, $port, clientName]

#[
type
  Either*[A, B] = object
    isLeft: bool
    a: A
    b: B

proc receiveEither(msgA: Future[Message], msgB: Future[Message]): Future[(bool, Message)] =
  result = newFuture[seq[A]](fromProc = "all")
  var
    items = newSeq[A](fs.len)
    count = 0

  for i, f in fs:
    f.callback = proc(g: Future[A]) =
      items[i] = g.read
      count += 1
      if count == fs.len:
        result.complete(items)
]#
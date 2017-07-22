import asyncnet, asyncdispatch
import nativesockets
import marshal
import strutils
import messages
from logger import nil


proc `$`*(socket: AsyncSocket): string =
  let socketHandle = socket.getFd()
  let (address, port) = socketHandle.getPeerAddr(socketHandle.getSockDomain())
  result = "$1:$2" % [address, $port]


proc showConnectionDetails*(socket: AsyncSocket, clientName: string) =
  logger.info("Received connection from $1 ($2)" % [$socket, clientName])


proc connectRetrying*(socket: AsyncSocket, url: string, port: Port) {.async.} =
  var connected = false
  while not connected:
    logger.info("Trying to connect to $1:$2" % [url, $port])
    let fut = socket.connect(url, port)
    yield fut
    if not fut.failed:
      connected = true
    else:
      await sleepAsync(1000)


proc sendMsg*[T](socket: AsyncSocket, x: T) {.async.} =
  var msg = $$x
  var msgSize = msg.len.int
  logger.debug("sending msgSize = ", msgSize)
  await socket.send(msgSize.addr, sizeOf(int))
  logger.debug("sending msg = ", msg)
  await socket.send(msg)


proc receiveMsg*(socket: AsyncSocket, T: typedesc): Future[T] {.async.} =
  logger.debug("Trying to receive message from ", $socket)

  var msgSize: int

  let futNumRead = socket.recvInto(msgSize.addr, sizeOf(int))
  yield futNumRead
  if futNumRead.failed():
    socket.close()
  else:
    let numRead = futNumRead.read()
    if numRead != sizeOf(int):
      logger.warn("Expected to read ", sizeOf(int), " bytes, but read: ", numRead)
      socket.close()

    else:
      let futRawMsg = socket.recv(msgSize)
      yield futRawMsg
      if futRawMsg.failed():
        socket.close()
      else:
        let rawMsg = futRawMsg.read()
        if rawMsg.len != msgSize:
          logger.warn("Expected to read ", msgSize, " bytes, but read: ", rawMsg.len)
          socket.close()
        else:
          result = to[T](rawMsg)


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
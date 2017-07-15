import asyncnet, asyncdispatch
import nativesockets
import marshal
import strutils


proc sendMsg*[T](socket: AsyncSocket, x: T) {.async.} =
  var msg = $$x
  var msgSize = msg.len.int
  await socket.send(msgSize.addr, sizeOf(int))
  await socket.send(msg)


proc receiveMsg*(socket: AsyncSocket, T: typedesc): Future[T] {.async.} =
  var msgSize: int

  echo "trying to read size of message"
  let numRead = await socket.recvInto(msgSize.addr, sizeOf(int))
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
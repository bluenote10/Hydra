
type

  MsgKind* {.pure.} = enum
    # uninitialized case so that receiveMsg return disconnect on no message
    SocketDisconnected = 0,
    RegisterWorker,
    RegisterDriver,
    RemoteCall,
    PushData,
    PullData,

  Message* = object
    case kind*: MsgKind
    of MsgKind.RemoteCall:
      procId*: int
      args*: seq[string]
      resultKey*: string
    of MsgKind.PushData:
      keyPush*: string
      data*: string
      serializerId*: int
    of MsgKind.PullData:
      keyPull*: string
      #serializerId*: int
    else:
      discard


proc msgSocketDisconnected*(): Message =
  Message(kind: MsgKind.SocketDisconnected)

proc msgRegisterWorker*(): Message =
  Message(kind: MsgKind.RegisterWorker)

proc msgRegisterDriver*(): Message =
  Message(kind: MsgKind.RegisterDriver)

proc msgPushData*(key: string, data: string, serializerId: int): Message =
  Message(kind: MsgKind.PushData, keyPush: key, data: data, serializerId: serializerId)

proc msgPullData*(key: string, data: string, serializerId: int): Message =
  Message(kind: MsgKind.PullData, keyPull: key)

proc msgRemoteCall*(procId: int, args: seq[string], resultKey: string): Message =
  Message(kind: MsgKind.RemoteCall, procId: procId, args: args, resultKey: resultKey)


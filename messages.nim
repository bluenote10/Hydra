
type

  MsgKind* {.pure.} = enum
    # uninitialized case so that receiveMsg return disconnect on no message
    SocketDisconnected = 0,
    RegisterWorker,
    RegisterDriver,
    RemoteCall,
    PushData,
    PullData,
    PureData,

  # TODO: This approach sucks due to the restriction of not
  # having shared fields. Do we need a hierarchy? But we can't
  # marshal the runtime type of a message :(
  Message* = object
    case kind*: MsgKind
    of MsgKind.RemoteCall:
      procId*: int
      args*: seq[string]
      resultKey*: string
    of MsgKind.PushData:
      keyPush*: string
      data*: string
      serializerIdPush*: int
    of MsgKind.PullData:
      keyPull*: string
      serializerIdPull*: int
    of MsgKind.PureData:
      pureData*: string
    else:
      discard


proc msgSocketDisconnected*(): Message =
  Message(kind: MsgKind.SocketDisconnected)

proc msgRegisterWorker*(): Message =
  Message(kind: MsgKind.RegisterWorker)

proc msgRegisterDriver*(): Message =
  Message(kind: MsgKind.RegisterDriver)

proc msgPushData*(key: string, data: string, serializerId: int): Message =
  Message(kind: MsgKind.PushData, keyPush: key, data: data, serializerIdPush: serializerId)

proc msgPullData*(key: string, serializerId: int): Message =
  Message(kind: MsgKind.PullData, keyPull: key, serializerIdPull: serializerId)

proc msgPureData*(data: string): Message =
  Message(kind: MsgKind.PureData, pureData: data)

proc msgRemoteCall*(procId: int, args: seq[string], resultKey: string): Message =
  Message(kind: MsgKind.RemoteCall, procId: procId, args: args, resultKey: resultKey)


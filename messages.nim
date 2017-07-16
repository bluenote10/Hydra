
type

  MsgKind* {.pure.} = enum
    RegisterWorker,
    RegisterDriver,
    RemoteCall,

  Message* = object
    case kind*: MsgKind
    of MsgKind.RemoteCall:
      procId*: int
    else:
      discard


proc msgRegisterWorker*(): Message =
  Message(kind: MsgKind.RegisterWorker)

proc msgRegisterDriver*(): Message =
  Message(kind: MsgKind.RegisterDriver)

proc msgRemoteCall*(procId: int): Message =
  Message(kind: MsgKind.RemoteCall, procId: procId)

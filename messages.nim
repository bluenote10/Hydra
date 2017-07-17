
type

  MsgKind* {.pure.} = enum
    RegisterWorker,
    RegisterDriver,
    RemoteCall,
    RegisterData,

  Message* = object
    case kind*: MsgKind
    of MsgKind.RemoteCall:
      procId*: int
      args*: seq[string]
    of MsgKind.RegisterData:
      key*: string
      data*: string
    else:
      discard


proc msgRegisterWorker*(): Message =
  Message(kind: MsgKind.RegisterWorker)

proc msgRegisterDriver*(): Message =
  Message(kind: MsgKind.RegisterDriver)

proc msgRegisterData*(key: string, data: string): Message =
  Message(kind: MsgKind.RegisterData, key: key, data: data)

proc msgRemoteCall*(procId: int, args: seq[string]): Message =
  Message(kind: MsgKind.RemoteCall, procId: procId, args: args)

import remote

type
  ProcId = int

  Node = ref object
    key: string
    procId: ProcId


proc hey(i: int): int {.remote.} = i

template node(keyName: string, p: untyped): untyped =
  Node(key: keyName, procId: lookupProc(p))

let n1 = Node(key: "i", procId: lookupProc(hey))

let n2 = node("i", hey)


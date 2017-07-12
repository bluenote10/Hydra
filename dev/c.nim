import b

proc test() {.remote.} =
  echo "client"

test()
hiddenProc()

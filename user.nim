import remote as remote_module
import serialization

proc square(x: int): int {.remote.} = x*x
proc myCubic(x: float): float {.remote.} = x*x*x

# proc nonRemoteProc() = discard

proc main() =
  echo genericCall(square, store(4)).restore(int)
  echo genericCall(myCubic, store(2.0)).restore(float)

main()
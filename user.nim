import remote as remote_module

proc mySquare(x: string): string {.remote.} = "userSquared"

proc myCubic(x: string): string {.remote.} = "userCubic"

echo genericCall(2, "")
echo genericCall(3, "")

echo genericCall(mySquare, "")
echo genericCall(myCubic, "")

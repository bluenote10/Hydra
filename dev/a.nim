import macros

proc genericProc*[T](x: T): T = x * x

var x = 2

proc buildProcHelper*(): NimNode {.compileTime.} =

  template build() {.dirty.} =
    proc hiddenProc() =
      bind x, genericProc
      echo x
      echo genericProc(4)

  result = getAst(build()) # [0]

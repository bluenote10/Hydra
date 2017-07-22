import os
import strutils
import tables
import times

import ../columns

# template to simplify timed execution
template runTimed(label, body: untyped) =
  let t1 = epochTime()
  body
  let t2 = epochTime()
  let runtime = (t2 - t1) * 1000
  echo label, ": ", runtime


proc main() =
  if paramCount() != 1:
    echo "ERROR: Expected argument N."
    quit(1)
  let N = paramStr(1).parseInt

  runTimed "int16":
    block:
      let col = newCol[int16](N)
  runTimed "int32":
    block:
      let col = newCol[int32](N)
  runTimed "int64":
    block:
      let col = newCol[int64](N)
  runTimed "float32":
    block:
      let col = newCol[float32](N)
  runTimed "float64":
    block:
      let col = newCol[float64](N)


  let col = newCol[float32](N)
  runTimed "mean int":
    let mean = col.mean()
  assert mean > 0


when isMainModule:
  main()

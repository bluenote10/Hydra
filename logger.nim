import macros
import times
import boost.richstring

type
  Level = enum
    Debug = "DEBUG",
    Info = "INFO",
    Warn = "WARN",
    Error = "ERROR"

var level: Level = Debug


macro appendVarargToCall(c: untyped, prefix: string, e: untyped): untyped =
  result = c
  result.add(prefix)
  for a in e.children:
    result.add(a)


template log*(level: Level, args: varargs[string, `$`]) {.dirty.} =
  ## Logs a message to all registered handlers at the given level.

  if level >= logger.level:
    let time = getClockStr()
    let io = instantiationInfo()
    #let prefix = time & " | " & io.filename & ":" & $io.line & " | " & $level & " | "
    let file = fmt"${io.filename}:${io.line}"
    let prefix = fmt "$time | ${file}%-30s | $level%-5s | "
    appendVarargToCall(echo(), prefix, args)

template debug*(args: varargs[string, `$`]) =
  log(Debug, args)

template info*(args: varargs[string, `$`]) =
  log(Info, args)

template warn*(args: varargs[string, `$`]) =
  log(Warn, args)

template error*(args: varargs[string, `$`]) =
  log(Error, args)


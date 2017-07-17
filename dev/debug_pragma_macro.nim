import macros

import ../remote

macro annotate(n: untyped): untyped = n

proc test1(i: int): int {.annotate.} = 0
proc test2(): int {.annotate.} = 0
proc test3() {.annotate.} = discard

proc rtest1(i: int): int {.remote.} = 0
proc rtest2(): int {.remote.} = 0
proc rtest3() {.remote.} = discard
import os

import master
import worker
import driver


proc launch*(clientApp: ClientApp) =
  let args = commandLineParams()

  if args.len != 1:
    echo "Error: wrong number of arguments"
    quit 1

  elif args[0] == "master":
    runMaster()

  elif args[0] == "worker":
    runWorker()

  elif args[0] == "driver":
    runDriver(clientApp)

  else:
    echo "Error: Unknown mode '", args[0], "'"


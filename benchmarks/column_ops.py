#!/usr/bin/env python

from __future__ import division, print_function

import numpy as np
import pandas as pd
import sys
import time
import gc


class TimedContext(object):

    def __init__(self, label):
        self.label = label

    def __enter__(self):
        self.t1 = time.time()

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.t2 = time.time()
        runtime = (self.t2 - self.t1) * 1000
        print("{:<60s} {:6.3f} ms".format(self.label, runtime))
        gc.collect()


def generate_range_np(N, dtype):
    return np.arange(0, N, dtype=dtype)


def bench_construction(N):
    print(" *** Benchmark construction")
    with TimedContext("Generating np.int16"):
        arr = generate_range_np(N, np.int16)
        del arr

    with TimedContext("Generating np.int32"):
        arr = generate_range_np(N, np.int32)
        del arr

    with TimedContext("Generating np.int64"):
        arr = generate_range_np(N, np.int64)
        del arr

    with TimedContext("Generating np.float32"):
        arr = generate_range_np(N, np.float32)
        del arr

    with TimedContext("Generating np.float64"):
        arr = generate_range_np(N, np.float64)
        del arr


def bench_mean(N):
    print(" *** Benchmark mean")
    dtypes = [np.int16, np.int32, np.int64, np.float32, np.float64]
    for dtype in dtypes:
        arr = generate_range_np(N, dtype)
        with TimedContext("Mean {}".format(dtype)):
            mean = arr.mean()
        assert mean > 0
        del arr
        gc.collect()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("ERROR: Expected argument N.")
        sys.exit(1)
    else:
        N = int(sys.argv[1])

    bench_construction(N)
    bench_mean(N)

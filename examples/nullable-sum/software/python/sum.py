# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import pyarrow as pa
import pyfletcher as pf
import numpy as np
import timeit
import sys
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("recordbatch_path")
    args = parser.parse_args()

    # Set up a RecordBatch reader and read the RecordBatch.
    reader = pa.RecordBatchFileReader(args.recordbatch_path)
    batch = reader.get_batch(0)

    platform = pf.Platform()                         # Create an interface to an auto-detected FPGA Platform.
    platform.init()                                  # Initialize the Platform.

    context = pf.Context(platform)                   # Create a Context for our data on the Platform.
    context.queue_record_batch(batch)                # Queue the RecordBatch to the Context.
    context.enable()                                 # Enable the Context, (potentially transferring the data to FPGA).

    kernel = pf.Kernel(context)                      # Set up an interface to the Kernel, supplying the Context.
    kernel.start()                                   # Start the kernel.
    kernel.wait_for_finish()                         # Wait for the kernel to finish.

    result = kernel.get_return(np.dtype(np.uint32))  # Obtain the result.
    print("Sum: " + str(result))                     # Print the result.

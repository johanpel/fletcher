# Fletcher C++ Run-time Library

The Fletcher C++ Run-time Library enables support for Fletcher-based accelerated
applications.

# Build & install

## Requirements

- [Apache Arrow 4.0+ C++ run-time and development headers.](https://arrow.apache.org/install)
- A C++17 compliant compiler
- CMake 3.14

## Build

```console
mkdir build
cmake ..
make
sudo make install
```

## Example usage

Include:

```c++
#include <fletcher/api.h>
```

Example snippet:

```c++
using fletcher::Platform;
using fletcher::Context;
using fletcher::Kernel;

// Given a RecordBatch:
std::shared_ptr<arrow::RecordBatch> batch = ...

std::shared_ptr<Platform> platform;
std::shared_ptr<Context> context;

Platform::Make(&platform);                // Create an interface to an auto-detected FPGA Platform.
platform->Init();                         // Initialize the Platform.

Context::Make(&context, platform);        // Create a Context for our data on the Platform.
context->QueueRecordBatch(number_batch);  // Queue the RecordBatch to the Context.
context->Enable();                        // Enable the Context, (potentially transferring the data to FPGA).

Kernel kernel(context);                   // Set up an interface to the Kernel, supplying the Context.
kernel.Start();                           // Start the kernel.
kernel.PollUntilDone();                   // Wait for the kernel to finish.

kernel.GetReturn(&result);                // Obtain the result.
```

# Documentation

[C++ API Documentation](https://abs-tudelft.github.io/fletcher/api/fletcher-cpp/)

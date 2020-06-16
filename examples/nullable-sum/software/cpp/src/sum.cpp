// Copyright 2018 Delft University of Technology
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <arrow/api.h>
#include <fletcher/api.h>

#include <memory>
#include <iostream>

/**
 * Main function for the Sum example.
 */
int main(int argc, char **argv) {
  // Check number of arguments.
  if (argc != 2) {
    std::cerr << "Incorrect number of arguments. Usage: sum path/to/recordbatch.rb" << std::endl;
    return -1;
  }

  std::vector<std::shared_ptr<arrow::RecordBatch>> batches;
  std::shared_ptr<arrow::RecordBatch> number_batch;

  // Attempt to read the RecordBatch from the supplied argument.
  fletcher::ReadRecordBatchesFromFile(argv[1], &batches);

  // RecordBatch should contain exactly one batch.
  if (batches.size() != 1) {
    std::cerr << "File did not contain any Arrow RecordBatches." << std::endl;
    return -1;
  }

  // The only RecordBatch in the file is our RecordBatch with the numbers.
  number_batch = batches[0];

  fletcher::Status status;
  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;

  // Create a Fletcher platform object, attempting to autodetect the platform.
  status = fletcher::Platform::Make(&platform);

  if (!status.ok()) {
    std::cerr << "Could not create Fletcher platform." << std::endl;
    return -1;
  }

  // Initialize the platform.
  status = platform->Init();

  if (!status.ok()) {
    std::cerr << "Could not create Fletcher platform." << std::endl;
    return -1;
  }

  // Create a context for our application on the platform.
  status = fletcher::Context::Make(&context, platform);

  if (!status.ok()) {
    std::cerr << "Could not create Fletcher context." << std::endl;
    return -1;
  }

  // Queue the recordbatch to our context.
  status = context->QueueRecordBatch(number_batch);

  if (!status.ok()) {
    std::cerr << "Could not queue the RecordBatch to the context." << std::endl;
    return -1;
  }

  // "Enable" the context, potentially copying the recordbatch to the device. This depends on your platform.
  // AWS EC2 F1 requires a copy, but OpenPOWER SNAP doesn't.
  context->Enable();

  if (!status.ok()) {
    std::cerr << "Could not enable the context." << std::endl;
    return -1;
  }

  // Create a kernel based on the context.
  fletcher::Kernel kernel(context);

  // Start the kernel.
  status = kernel.Start();

  if (!status.ok()) {
    std::cerr << "Could not start the kernel." << std::endl;
    return -1;
  }

  // Wait for the kernel to finish.
  status = kernel.WaitForFinish();

  if (!status.ok()) {
    std::cerr << "Something went wrong waiting for the kernel to finish." << std::endl;
    return -1;
  }

  // Obtain the return value.
  uint32_t return_value_0;
  uint32_t return_value_1;
  status = kernel.GetReturn(&return_value_0, &return_value_1);

  if (!status.ok()) {
    std::cerr << "Could not obtain the return value." << std::endl;
    return -1;
  }

  // Print the return value.
  std::cout << *reinterpret_cast<int32_t*>(&return_value_0) << std::endl;

  return 0;
}

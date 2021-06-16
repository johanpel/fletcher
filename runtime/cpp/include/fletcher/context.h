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

#pragma once

#include <arrow/api.h>
#include <fletcher/common.h>
#include <utility>
#include <vector>
#include <memory>
#include <iostream>

#include "fletcher/platform.h"
#include "fletcher/status.h"

namespace fletcher {

using fletcher::Mode;

/// Enumeration for different types of memory management.
enum class MemType {
  /**
   * @brief Apply the least effort to make the data available to the device.
   *
   * For platforms where the device may access host memory directly, ANY will not copy data to device on-board
   * memory to make it available to the device. If the platform requires a copy to on-board memory, then this will
   * behave the same as the CACHE option.
   */
      ANY,

  /**
   * @brief Cache the data to on-board memory of the device.
   *
   * If available, this forces the data to be copied to device on-board memory (e.g. some seperate DRAM chips sitting
   * on the accelerator PCB next to the FPGA, but it could be HBM on top of the FPGA fabric in the same chip, or
   * BRAM. This depends on the platform).
   *
   * Selecting CACHE may result in higher performance if there is data reuse by the kernel, but may result in lower
   * performance if the data is not reused by the kernel (for example fully streamable kernels).
   */
      CACHE,

  /**
   * @brief Allocate a buffer for the data on the on-board memory of the device, but don't copy the buffer contents to it.
   *
   * If available, this forces a buffer to be allocated on device on-board memory (e.g. some seperate DRAM chips sitting
   * on the accelerator PCB next to the FPGA, but it could be HBM on top of the FPGA fabric in the same chip, or
   * BRAM. This depends on the platform). However, the data currently in the provided buffer is not copied to the device;
   * the device memory is left uninitialized. This is useful for output buffers, or if you want to handle initialization
   * manually.
   */
      ALLOC_ONLY
};

/// A buffer on the device
struct DeviceBuffer {
  /// The host-side mirror address of this buffer.
  const uint8_t *host_address = nullptr;
  /// The device-side address of this buffer.
  da_t device_address = D_NULLPTR;
  /// The size of this buffer in bytes.
  int64_t size = 0;

  /// The memory type of this buffer.
  MemType memory = MemType::CACHE;
  /// The access mode as seen by the accelerator kernel.
  Mode mode = Mode::READ;

  /// Whether this buffer has been made available to the device.
  bool available_to_device = false;
  /// Whether this buffer was allocated on the device using Platform malloc.
  bool was_alloced = false;

  /// @brief Construct a default DeviceBuffer.
  DeviceBuffer() = default;

  /// @brief Construct a new DeviceBuffer.
  DeviceBuffer(const uint8_t *host_address, int64_t size, MemType type, Mode access_mode)
      : host_address(host_address), size(size), memory(type), mode(access_mode) {}
};

/// A Context for a platform where a RecordBatches can be prepared for processing by the Kernel.
class Context {
 public:
  /**
   * @brief Context constructor.
   * @param[in] platform  A platform to construct the context on.
   */
  explicit Context(std::shared_ptr<Platform> platform) : platform_(std::move(platform)) {}

  /// @brief Deconstruct the context object, freeing all allocated device buffers.
  ~Context();

  /**
   * @brief Create a new context on a specific platform.
   * @param[out] context  A pointer to a shared pointer that will own the new Context.
   * @param[in] platform  The platform to create the Context on.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  static Status Make(std::shared_ptr<Context> *context, const std::shared_ptr<Platform> &platform);

  /**
   * @brief Enqueue an arrow::RecordBatch for usage on the device.
   *
   * This function utilizes Arrow metadata in the schema of the RecordBatch to determine whether or not some field
   * (i.e. some Array in the internal structure) will be used on the device.
   *
   * @param[in] record_batch  The arrow::RecordBatch to queue
   * @param[in] mem_type      Force caching; i.e. the RecordBatch is guaranteed to be copied to on-board memory.
   * @return Status::OK() if successful, otherwise a descriptive error status.
   */
  Status QueueRecordBatch(const std::shared_ptr<arrow::RecordBatch> &record_batch,
                          MemType mem_type = MemType::ANY);

  /// @brief Obtain the size (in bytes) of all buffers currently enqueued.
  size_t GetQueueSize() const;

  /// @brief Enable the usage of the enqueued buffers by the device.
  Status Enable();

  /// @brief Return the platform this context is active on.
  std::shared_ptr<Platform> platform() const { return platform_; }

  /// @brief Return the number of device buffers in this context.
  uint64_t num_buffers() const;

  /**
   * @brief Return the i-th DeviceBuffer of this context.
   * @param[in] i The index of the DeviceBuffer to return.
   * @return The i-th DeviceBuffer.
   */
  DeviceBuffer device_buffer(size_t i) const { return device_buffers_[i]; }

  /// @brief Return the number of RecordBatches in this context.
  uint64_t num_recordbatches() const { return host_batches_.size(); }

  /**
   * @brief Return the i-th arrow::RecordBatch of this context.
   * @param[in] i The index of the arrow::RecordBatch to return.
   * @return A shared pointer to the arrow::RecordBatch.
   */
  std::shared_ptr<arrow::RecordBatch> recordbatch(size_t i) const { return host_batches_[i]; }

 protected:
  /// The platform this context is running on.
  std::shared_ptr<Platform> platform_;
  /// The RecordBatches on the host side.
  std::vector<std::shared_ptr<arrow::RecordBatch>> host_batches_;
  /// The descriptions of the RecordBatches on the host side.
  std::vector<RecordBatchDescription> host_batch_desc_;
  /// Whether the RecordBatch must be prepared or cached for the device.
  std::vector<MemType> host_batch_memtype_;
  /// Prepared/cached buffers on the device.
  std::vector<DeviceBuffer> device_buffers_;
};

}  // namespace fletcher

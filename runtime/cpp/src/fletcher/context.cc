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
#include <fletcher/common.h>
#include <vector>
#include <memory>

#include "fletcher/context.h"

namespace fletcher {

Status Context::Make(std::shared_ptr<Context> *context, const std::shared_ptr<Platform> &platform) {
  *context = std::make_shared<Context>(platform);
  return Status::OK();
}

Context::~Context() {
  Status status;
  FLETCHER_LOG(DEBUG, "Destructing Context...");
  for (const auto &buf : device_buffers_) {
    if (buf.was_alloced) {
      status = platform_->DeviceFree(buf.device_address);
      if (!status.ok()) {
        FLETCHER_LOG(ERROR, "Could not properly free context. Device memory may be corrupted. "
                            "Status: " + status.message);
      }
    }
  }
}

Status Context::Enable() {
  auto num_batches = host_batches_.size();
  // Sanity check
  assert(num_batches == host_batch_desc_.size());
  assert(num_batches == host_batch_memtype_.size());

  FLETCHER_LOG(DEBUG, "Enabling context for " << num_batches << " queued RecordBatch(es)");

  // Loop over all batches queued on host
  for (size_t i = 0; i < num_batches; i++) {
    auto rbd = host_batch_desc_[i];
    auto type = host_batch_memtype_[i];
    for (const auto &f : rbd.fields) {
      for (const auto &b : f.buffers) {
        fletcher::Status status;
        DeviceBuffer device_buf(b.raw_buffer_, b.size_, type, rbd.mode);
        if (type == MemType::ANY) {
          status = platform_->PrepareHostBuffer(device_buf.host_address,
                                                &device_buf.device_address,
                                                device_buf.size,
                                                &device_buf.was_alloced);
        } else if (type == MemType::CACHE) {
          status = platform_->CacheHostBuffer(device_buf.host_address,
                                              &device_buf.device_address,
                                              device_buf.size);
          // Cache always allocates on device.
          device_buf.was_alloced = true;
        } else if (type == MemType::ALLOC_ONLY) {
          status = platform_->DeviceMalloc(&device_buf.device_address,
                                           device_buf.size);
          device_buf.was_alloced = true;
        } else {
          status = Status::ERROR("Invalid / unsupported MemType.");
        }
        if (!status.ok()) {
          return status;
        }
        device_buffers_.push_back(device_buf);
      }
    }
  }

  FLETCHER_LOG(DEBUG, "Context contains " << device_buffers_.size() << " device buffer(s).");
  return Status::OK();
}

Status Context::QueueRecordBatch(const std::shared_ptr<arrow::RecordBatch> &record_batch, MemType mem_type) {
  // Sanity check the recordbatch
  if (record_batch == nullptr) {
    return Status::ERROR("RecordBatch is nullptr.");
  }

  host_batches_.push_back(record_batch);

  // Create a description of the RecordBatch
  RecordBatchDescription rbd;
  RecordBatchAnalyzer rba(&rbd);
  rba.Analyze(*record_batch);
  host_batch_desc_.push_back(rbd);

  // Put the desired memory type of the RecordBatch
  host_batch_memtype_.push_back(mem_type);

  return Status::OK();
}

uint64_t Context::num_buffers() const {
  uint64_t ret = 0;
  for (const auto &rbd : host_batch_desc_) {
    for (const auto &f : rbd.fields) {
      ret += f.buffers.size();
    }
  }
  return ret;
}

size_t Context::GetQueueSize() const {
  size_t size = 0;
  for (const auto &desc : host_batch_desc_) {
    for (const auto &f : desc.fields) {
      for (const auto &buf : f.buffers) {
        size += buf.size_;
      }
    }
  }
  return size;
}

}  // namespace fletcher

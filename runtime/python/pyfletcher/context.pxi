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

cdef class DeviceBuffer():
    """Python wrapper for Fletcher DeviceBuffer."""
    
    # The C++ device buffer this PyObject holds
    cdef CDeviceBuffer c_device_buffer 

    def __cinit__(self):
        self.c_device_buffer = CDeviceBuffer()
        
    # Construct from an existing CDeviceBuffer
    cdef from_reference(self, CDeviceBuffer buf):
        self.c_device_buffer = buf
    
    
cdef class Context():
    """Python wrapper for Fletcher Context.

    Args:
        Platform this context should run on.

    """
    cdef:
        shared_ptr[CContext] context

    def __cinit__(self, Platform platform):
        check_fletcher_status(CContext.Make(&self.context, platform.platform))

    cdef from_pointer(self, shared_ptr[CContext] context):
        self.context = context

    def queue_record_batch(self, record_batch, mem_type='any'):
        """Enqueue an arrow::RecordBatch for usage preparation on the device.

        Args:
            record_batch : Arrow RecordBatch to queue
            memtype (str): Memory type: - 'any' results in least effort to make data available to FPGA (depending on the platform implementation).
                                        - 'cache' force copy to accelerator on-board DRAM memory, if available.
                                        - 'alloc_only' force allocation on accelerator on-board DRAM memory (if available), but don't copy.

        """
        
        cdef MemType queue_mem_type

        if mem_type == "any":
            queue_mem_type = MemType.ANY
        elif mem_type == "cache":
            queue_mem_type = MemType.CACHE
        elif mem_type == "alloc_only":
            queue_mem_type = MemType.ALLOC_ONLY
        else:
            raise ValueError("mem_type argument can be only 'any' or 'cache'")
        
        check_fletcher_status(self.context.get().QueueRecordBatch(pyarrow_unwrap_batch(record_batch), queue_mem_type))

    def get_queue_size(self):
        """Obtain the size (in bytes) of all buffers currently enqueued.

        Returns:
            queue_size

        """
        return self.context.get().GetQueueSize()

    def num_buffers(self):
        """Return the number of buffers in this context.

        Returns:
            num_buffers

        """
        return self.context.get().num_buffers()

    def get_device_buffer(self, size_t buffer_index):
        """Get a list of device buffers

        Args:
            buffer_index: Index of the buffer in this context.

        Returns:

        """
        cdef DeviceBuffer result = Context.__new__(Context)
        result.from_reference(self.context.get().device_buffer(buffer_index))
        return result

    def enable(self):
        check_fletcher_status(self.context.get().Enable())

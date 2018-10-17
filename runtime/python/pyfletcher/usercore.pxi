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

cdef class UserCore:
    cdef:
        shared_ptr[CPlatform] ucplatform
        shared_ptr[CUserCore] usercore

    def __cinit__(self, Platform platform):
        self.usercore.reset(new CUserCore(platform.platform))
        self.ucplatform = platform.platform

    cdef from_pointer(self, const shared_ptr[CUserCore]& usercore):
        self.usercore = usercore
        self.ucplatform = self.usercore.get().platform()

    def implements_schema(self, schema):
        return self.usercore.get().implementsSchema(pyarrow_unwrap_schema(schema))

    def reset(self):
        check_fletcher_status(self.usercore.get().reset())

    def set_range(self, uint32_t first, uint32_t last):
        check_fletcher_status(self.usercore.get().setRange(first, last))

    # Todo: To be implemented
    def set_arguments(self, list arguments):
        for argument in arguments:
            pass

    def start(self):
        check_fletcher_status(self.usercore.get().start())

    def get_status(self):
        cdef uint32_t status
        check_fletcher_status(self.usercore.get().getStatus(&status))
        return status

    def get_return(self):
        cdef uint32_t hi
        cdef uint32_t lo
        cdef uint64_t ret

        check_fletcher_status(self.usercore.get().getReturn(&lo, &hi))
        ret = (<uint64_t>hi << 32) + lo

        return ret

    def wait_for_finish(self, poll_interval_usec=0):
        check_fletcher_status(self.usercore.get().waitForFinish(poll_interval_usec))

    def platform(self):
        return pyfletcher_wrap_platform(self.ucplatform)
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

# distutils: language = c++

cimport cython

from libcpp.memory cimport shared_ptr
from libc.stdint cimport *
from libcpp.string cimport string as cpp_string
from libcpp.vector cimport vector
from libcpp cimport bool as cpp_bool

from pyarrow.lib cimport *


cdef extern from "<memory>":
    shared_ptr[CEchoPlatform] base_to_echo "std::static_pointer_cast<fletcher::EchoPlatform>" (shared_ptr[CFPGAPlatform])
    #shared_ptr[CAWSPlatform] base_to_aws "std::static_pointer_cast<fletcher::AWSPlatform>" (shared_ptr[CFPGAPlatform])
    #shared_ptr[CSNAPPlatform] base_to_snap "std::static_pointer_cast<fletcher::SNAPPlatform>" (shared_ptr[CFPGAPlatform])

cdef extern from "fletcher/fletcher.h" namespace "fletcher" nogil:
    ctypedef unsigned long long fa_t
    ctypedef unsigned int fr_t

    cdef cppclass CFPGAPlatform" fletcher::FPGAPlatform":
        uint64_t prepare_column_chunks(const shared_ptr[CColumn]& column)
        uint64_t argument_offset()
        cpp_string name()
        int write_mmio(uint64_t offset, fr_t value)
        int read_mmio(uint64_t offset, fr_t *dest)
        cpp_bool good()

    cdef cppclass CEchoPlatform" fletcher::EchoPlatform"(CFPGAPlatform):
        CEchoPlatform() except +


    #cdef cppclass CAWSPlatform" fletcher::AWSPlatform"(CFPGAPlatform):
    #    CAWSPlatform(int slot_id, int pf_id, int bar_id) except +
    #    void set_alignment(uint64_t alignment)

    #cdef cppclass CSNAPPlatform" fletcher::SNAPPlatform"(CFPGAPlatform):
    #    CSNAPPlatform(int card_no, uint32_t action_type, cpp_bool sim) except +
    #    void set_alignment(uint64_t alignment)


    ctypedef enum uc_stat:
        FAILURE,
        SUCCESS

    cdef cppclass CUserCore" fletcher::UserCore":
        CUserCore(shared_ptr[CFPGAPlatform] platform) except +
        cpp_bool implements_schema(const shared_ptr[CSchema]& schema)
        uc_stat reset()
        uc_stat set_range(fr_t first, fr_t last)
        # Todo: set_arguments wont work like this. Maybe make a python implementation?
        uc_stat set_arguments(vector[fr_t] arguments)
        uc_stat start()
        fr_t get_status()
        fa_t get_return()
        uc_stat wait_for_finish(unsigned int poll_interval_usec)
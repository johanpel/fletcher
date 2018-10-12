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

#include <memory>

#include "../src/platform.h"

int main() {
  std::shared_ptr<fletcher::Platform> platform;

  // Create
  fletcher::Platform::create(&platform).check();

  // Init
  platform->init().check();

  // Info:
  std::cout << "Platform name: " << platform->getName() << std::endl;

  // Malloc / free
  da_t a;
  platform->deviceMalloc(&a, 1024);
  platform->deviceFree(a);

  // MMIO:
  platform->writeMMIO(0, 0).check();
  uint32_t val;
  platform->readMMIO(0, &val).check();

  // Buffers:
  char buffer[128];
  platform->copyHostToDevice(reinterpret_cast<ha_t>(buffer), 0, sizeof(buffer)).check();
  platform->copyDeviceToHost(0, reinterpret_cast<ha_t>(buffer), sizeof(buffer)).check();

  // Terminate:
  platform->terminate().check();

  return EXIT_SUCCESS;
}

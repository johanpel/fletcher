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

#include "fletchgen/design.h"
#include "fletchgen/recordbatch.h"

namespace fletchgen {

fletchgen::Design fletchgen::Design::GenerateFrom(const std::shared_ptr<Options> &opts) {
  Design ret;
  ret.options = opts;

  // Read schemas
  LOG(INFO, "Reading Arrow Schema files.");
  ret.schemas = fletcher::readSchemasFromFiles(ret.options->schema_paths);
  LOG(INFO, "Creating SchemaSet.");
  ret.schema_set = SchemaSet::Make(ret.options->kernel_name, ret.schemas);

  // Generate all RecordBatchReaders
  for (const auto& fs : ret.schema_set->read_schemas) {
    LOG(INFO, "Generating RecordBatchReader for Schema: " + fs->name());
    auto reader = RecordBatchReader::Make(fs);
    ret.readers.push_back(reader);
  }

  LOG(INFO, "Generating Kernel...");
  ret.kernel = Kernel::Make(ret.options->kernel_name, ret.readers);

  //LOG(INFO, "Generating Mantle...");
  //ret.mantle = Mantle::Make(ret.schema_set);

  //LOG(INFO, "Generating Artery...");
  //ret.artery = Artery::Make(ret.options->kernel_name, nullptr, nullptr, {});

  //LOG(WARNING, "Generating Wrapper not yet implemented.");
  // TODO(johanpel) top level wrapper

  return ret;
}

std::deque<std::shared_ptr<cerata::Graph>> Design::GetAllComponents() {
  std::deque<std::shared_ptr<cerata::Graph>> ret;
  // Insert readers
  ret.insert(ret.begin(), readers.begin(), readers.end());
  ret.push_back(kernel);
  return ret;
}

}
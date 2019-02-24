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

#include "fletchgen/bus.h"

#include <memory>
#include <cerata/types.h>

#include "cerata/graphs.h"
#include "cerata/types.h"
#include "cerata/edges.h"
#include "cerata/arrays.h"

#include "fletchgen/basic_types.h"

namespace fletchgen {

using cerata::Parameter;
using cerata::Port;
using cerata::PortArray;
using cerata::intl;
using cerata::integer;
using cerata::string;
using cerata::strl;
using cerata::boolean;
using cerata::bool_true;
using cerata::bool_false;

std::shared_ptr<Component> BusReadArbiter() {
  auto nslaves = Parameter::Make("NUM_SLAVE_PORTS", integer(), intl<0>());
  auto slaves_rreq_array = PortArray::Make("bsv_rreq", bus_read_request(), nslaves, Port::Dir::IN);
  auto slaves_rdat_array = PortArray::Make("bsv_rdat", bus_read_data(), nslaves, Port::Dir::OUT);

  static auto ret = Component::Make("BusReadArbiterVec",
                                    {bus_addr_width(),
                                     bus_len_width(),
                                     bus_data_width(),
                                     nslaves,
                                     Parameter::Make("ARB_METHOD", string(), strl("ROUND-ROBIN")),
                                     Parameter::Make("MAX_OUTSTANDING", integer(), intl<4>()),
                                     Parameter::Make("RAM_CONFIG", string(), strl("")),
                                     Parameter::Make("SLV_REQ_SLICES", boolean(), bool_true()),
                                     Parameter::Make("MST_REQ_SLICE", boolean(), bool_true()),
                                     Parameter::Make("MST_DAT_SLICE", boolean(), bool_true()),
                                     Parameter::Make("SLV_DAT_SLICES", boolean(), bool_true()),
                                     Port::Make(bus_clk()),
                                     Port::Make(bus_reset()),
                                     Port::Make("mst_rreq", bus_read_request(), Port::Dir::OUT),
                                     Port::Make("mst_rdat", bus_read_data(), Port::Dir::IN),
                                     slaves_rreq_array,
                                     slaves_rdat_array
                                    });
  return ret;
}

Artery::Artery(std::shared_ptr<Node> address_width,
               std::shared_ptr<Node> master_width,
               std::deque<std::shared_ptr<Node>> slave_widths)
    : Component("artery"),
      address_width_(std::move(address_width)),
      master_width_(std::move(master_width)),
      slave_widths_(std::move(slave_widths)) {
  AddObject(bus_addr_width());
  AddObject(bus_data_width());
  // For each required slave width
  for (const auto &sw : slave_widths_) {
    // Create parameters
    auto par = Parameter::Make("NUM_SLV_W" + sw->ToString(), integer());
    AddObject(par);

    // Create ports
    auto req = PortArray::Make("bus" + sw->ToString() + "_rreq", bus_read_request(), par, Port::IN);
    auto dat = PortArray::Make("bus" + sw->ToString() + "_rdat", bus_read_data(sw), par, Port::OUT);
    AddObject(req);
    AddObject(dat);

    // Create a bus read arbiter vector instance
    auto inst = Instance::Make("brav" + sw->ToString() + "_inst", BusReadArbiter());

    // Set its parameters
    inst->par("bus_addr_width") <<= address_width_;
    inst->par("bus_data_width") <<= sw;

    // Connect its ports
    inst->porta("bsv_rreq")->Append() <<= req->Append();
    dat->Append() <<= inst->porta("bsv_rdat")->Append();

    AddChild(std::move(inst));
  }
}

std::shared_ptr<Artery> Artery::Make(std::shared_ptr<Node> address_width,
                                     std::shared_ptr<Node> master_width,
                                     std::deque<std::shared_ptr<Node>> slave_widths) {
  return std::make_shared<Artery>(address_width, master_width, slave_widths);
}

std::shared_ptr<PortArray> ArteryInstance::read_data(const std::shared_ptr<Node> &width) {
  return porta("bus" + width->ToString() + "_rdat");
}

std::shared_ptr<PortArray> ArteryInstance::read_request(const std::shared_ptr<Node> &width) {
  return porta("bus" + width->ToString() + "_rreq");
}

}  // namespace fletchgen
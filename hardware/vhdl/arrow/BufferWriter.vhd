-- Copyright 2018 Delft University of Technology
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.Streams.all;
use work.Utils.all;
use work.Arrow.all;

entity BufferWriter is
  generic (

    ---------------------------------------------------------------------------
    -- Bus metrics and configuration
    ---------------------------------------------------------------------------
    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Number of beats in a burst step.
    BUS_BURST_STEP_LEN          : natural := 4;

    -- Maximum number of beats in a burst.
    BUS_BURST_MAX_LEN           : natural := 16;

    ---------------------------------------------------------------------------
    -- Arrow metrics and configuration
    ---------------------------------------------------------------------------
    -- Index field width.
    INDEX_WIDTH                 : natural := 32;

    ---------------------------------------------------------------------------
    -- Datapath timing configuration
    ---------------------------------------------------------------------------
    -- Bus write buffer FIFO depth. The maximum number of outstanding requests 
    -- is approximately this number divided by the burst length. If set to 2, 
    -- a register slice is inserted instead of a FIFO. If set to 0, the buffers
    -- are omitted.
    BUS_FIFO_DEPTH              : natural := 16;
    
    ---------------------------------------------------------------------------
    -- Buffer metrics and configuration
    ---------------------------------------------------------------------------
    -- Buffer element width in bits.
    ELEMENT_WIDTH               : natural := 8;

    -- Whether this is a normal buffer or an index buffer.
    IS_INDEX_BUFFER             : boolean := false;

    -- Maximum number of elements returned per cycle. When more than 1,
    -- elements are returned LSB-aligned and LSB-first, along with a count
    -- field that indicates how many elementss are valid. A best-effort
    -- approach is utilized; no guarantees are made about how many elements
    -- are actually returned per cycle. This feature is not supported for index
    -- buffers.
    ELEMENT_COUNT_MAX           : natural := 1;

    -- Width of the vector indicating the number of valid elements. Must be at
    -- least 1 to prevent null ranges.
    ELEMENT_COUNT_WIDTH         : natural := 1;

    -- Command stream control vector width. This vector is propagated to the
    -- outgoing command stream, but isn't used otherwise. It is intended for
    -- control flags and base addresses for BufferWriters reading buffers that
    -- are indexed by this index buffer.
    CMD_CTRL_WIDTH              : natural := 1;

    -- Command stream tag width. This tag is propagated to the outgoing command
    -- stream and to the unlock stream. It is intended for chunk reference
    -- counting.
    CMD_TAG_WIDTH               : natural := 1

  );
  port (

    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferWriter.
    bus_clk                     : in  std_logic;
    bus_reset                   : in  std_logic;

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- accelerator side.
    acc_clk                     : in  std_logic;
    acc_reset                   : in  std_logic;

    ---------------------------------------------------------------------------
    -- Command streams
    ---------------------------------------------------------------------------
    -- If lastIdx is not zero, it is implied that the size of the buffer is
    -- known.
    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_baseAddr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic;
    cmdIn_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    -- Unlock stream output (accelerator clock domain). The tags received on 
    -- the incoming command stream are returned by this stream in order when 
    -- all bus requests assocated with the command have finished processing.
    unlock_valid                : out std_logic;
    unlock_ready                : in  std_logic := '1';
    unlock_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
    
    ---------------------------------------------------------------------------
    -- Input from accelerator
    ---------------------------------------------------------------------------
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    in_last                     : in  std_logic;
  
    ---------------------------------------------------------------------------
    -- Bus write channels
    ---------------------------------------------------------------------------
    -- Request channel
    bus_req_valid               : out std_logic;
    bus_req_ready               : in  std_logic;
    bus_req_addr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_req_len                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    
    -- Data channel
    bus_wrd_valid               : out std_logic;
    bus_wrd_ready               : in  std_logic;
    bus_wrd_data                : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_wrd_strobe              : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    bus_wrd_last                : out std_logic
    
    -- TODO in entity:
    --  - status/error flags

  );
end BufferWriter;

architecture Behavioral of BufferWriter is
  signal pre_valid              : std_logic;
  signal pre_ready              : std_logic;
  signal pre_data               : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal pre_strobe             : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal pre_last               : std_logic;
  
  signal req_ready       : std_logic;
  signal req_valid       : std_logic;
  signal req_addr        : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal req_len         : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  
  signal cmdIn_ready_pre        : std_logic;
  signal cmdIn_ready_cmd        : std_logic;
  signal cmdIn_ready_unl        : std_logic;
  signal cmdIn_valid_pre        : std_logic;
  signal cmdIn_valid_cmd        : std_logic;
  signal cmdIn_valid_unl        : std_logic;
  
  signal word_loaded            : std_logic;
  signal word_last              : std_logic;
  
  signal buffer_full            : std_logic;
  signal buffer_empty           : std_logic;
  
  signal int_bus_req_valid      : std_logic;
  signal int_bus_req_ready      : std_logic;
  signal int_bus_req_addr       : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal int_bus_req_len        : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal int_bus_wrd_valid      : std_logic;
  signal int_bus_wrd_ready      : std_logic;
  signal int_bus_wrd_data       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal int_bus_wrd_strobe     : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal int_bus_wrd_last       : std_logic;
    
  signal last_in_cmd            : std_logic;
  
  signal unl_valid              : std_logic;
  signal unl_ready              : std_logic := '1';
  signal unl_tag                : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
begin
  -----------------------------------------------------------------------------
  -- Input stream pre-processing
  -----------------------------------------------------------------------------
  -- Pre-processes the stream to align to burst steps and generates write
  -- strobes.

  pre_inst: BufferWriterPre
    generic map (
      INDEX_WIDTH               => INDEX_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      IS_INDEX_BUFFER           => IS_INDEX_BUFFER,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH,
      CMD_CTRL_WIDTH            => CMD_CTRL_WIDTH,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      clk                       => acc_clk,
      reset                     => acc_reset,

      cmdIn_valid               => cmdIn_valid_pre,
      cmdIn_ready               => cmdIn_ready_pre,
      cmdIn_firstIdx            => cmdIn_firstIdx,
      cmdIn_implicit            => cmdIn_implicit,

      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_dvalid                 => '1',
      in_data                   => in_data,
      in_count                  => in_count,
      in_last                   => in_last,

      out_valid                 => pre_valid,
      out_ready                 => pre_ready,
      out_data                  => pre_data,
      out_strobe                => pre_strobe,
      out_last                  => pre_last
    );

  cmdgen_inst: BufferWriterCmdGenBusReq
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      IS_INDEX_BUFFER           => IS_INDEX_BUFFER,
      CHECK_INDEX               => false
    )
    port map (
      clk                       => acc_clk,
      reset                     => acc_reset,
      cmdIn_valid               => cmdIn_valid_cmd,
      cmdIn_ready               => cmdIn_ready_cmd,
      cmdIn_firstIdx            => cmdIn_firstIdx,
      cmdIn_baseAddr            => cmdIn_baseAddr,
      cmdIn_implicit            => cmdIn_implicit,
      word_loaded               => word_loaded,
      word_last                 => word_last,
      busReq_valid              => req_valid,
      busReq_ready              => req_ready,
      busReq_addr               => req_addr,
      busReq_len                => req_len
    );
  
  word_loaded                   <= pre_valid and pre_ready;
  word_last                     <= pre_last and pre_valid and pre_ready;
  
  buffer_inst: BusWriteBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH, 
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => max(BUS_FIFO_DEPTH, BUS_BURST_MAX_LEN+1),
      RAM_CONFIG                => ""
    )
    port map (
      clk                       => acc_clk,
      reset                     => acc_reset,
      full                      => buffer_full,
      empty                     => buffer_empty,
      mst_req_valid             => int_bus_req_valid,
      mst_req_ready             => int_bus_req_ready,
      mst_req_addr              => int_bus_req_addr,
      mst_req_len               => int_bus_req_len,
      mst_wrd_valid             => int_bus_wrd_valid,
      mst_wrd_ready             => int_bus_wrd_ready,
      mst_wrd_data              => int_bus_wrd_data,
      mst_wrd_strobe            => int_bus_wrd_strobe,
      mst_wrd_last              => int_bus_wrd_last,
      mst_wrd_last_in_cmd       => last_in_cmd,
      slv_req_valid             => req_valid,
      slv_req_ready             => req_ready,
      slv_req_addr              => req_addr,
      slv_req_len               => req_len,
      slv_wrd_valid             => pre_valid,
      slv_wrd_ready             => pre_ready,
      slv_wrd_data              => pre_data,
      slv_wrd_strobe            => pre_strobe,
      slv_wrd_last              => pre_last
    );
    
  unlock_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => 2,
      DATA_WIDTH                => CMD_TAG_WIDTH
    )
    port map (
      clk                       => acc_clk,
      reset                     => acc_reset,

      in_valid                  => cmdIn_valid_unl,
      in_ready                  => cmdIn_ready_unl,
      in_data                   => cmdIn_tag,

      out_valid                 => unl_valid,
      out_ready                 => unl_ready,
      out_data                  => unl_tag
    );
  
  unlock_tag                    <= unl_tag;
  
  cmdIn_ready                   <= cmdIn_ready_pre and cmdIn_ready_cmd and cmdIn_ready_unl;

  cmdIn_valid_pre               <= cmdIn_valid and cmdIn_ready_cmd and cmdIn_ready_unl;
  cmdIn_valid_cmd               <= cmdIn_valid and cmdIn_ready_pre and cmdIn_ready_unl;
  cmdIn_valid_unl               <= cmdIn_valid and cmdIn_ready_pre and cmdIn_ready_cmd;
  
  int_bus_req_ready             <= bus_req_ready;
  bus_req_valid                 <= int_bus_req_valid;
  bus_req_addr                  <= int_bus_req_addr;
  bus_req_len                   <= int_bus_req_len;
  
  bus_wrd_data                  <= int_bus_wrd_data;
  bus_wrd_strobe                <= int_bus_wrd_strobe;
  bus_wrd_last                  <= int_bus_wrd_last;
  
  unlock_proc: process(unlock_ready, unl_valid, bus_wrd_ready, int_bus_wrd_valid, last_in_cmd)
  begin
    -- If a bus word write is valid
    if int_bus_wrd_valid = '1' then
      -- If this is the last word in the command and it was written
      if last_in_cmd = '1' and bus_wrd_ready = '1' then
        -- Let the unlock stream handshake
        unl_ready               <= unlock_ready;
        unlock_valid            <= unl_valid;
  
        -- Let the data stream handshake only when the unlock stream handshaked
        if unl_valid = '1' and unlock_ready = '1' then
          int_bus_wrd_ready     <= bus_wrd_ready;
          bus_wrd_valid         <= int_bus_wrd_valid;
        else
          int_bus_wrd_ready     <= '0';
          bus_wrd_valid         <= '0';
        end if;
      -- This is not the last word in the command, let the stream do its thing
      else
        unl_ready               <= '0';
        unlock_valid            <= '0';
        int_bus_wrd_ready       <= bus_wrd_ready;
        bus_wrd_valid           <= int_bus_wrd_valid;
      end if;
    else
      int_bus_wrd_ready         <= '0';
      bus_wrd_valid             <= '0';
      unl_ready                 <= '0';
      unlock_valid              <= '0';
    end if;
  end process;

end Behavioral;


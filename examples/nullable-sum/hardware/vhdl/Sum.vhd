-- Copyright 2018-2019 Delft University of Technology
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
use ieee.numeric_std.all;

-- This kernel sums the values of an integer column.

entity Sum is
  generic (
    INDEX_WIDTH : integer := 32;
    TAG_WIDTH   : integer := 1
  );
  port (
    kcd_clk                          : in  std_logic;
    kcd_reset                        : in  std_logic;
    ExampleBatch_number_valid        : in  std_logic;
    ExampleBatch_number_ready        : out std_logic;
    ExampleBatch_number_dvalid       : in  std_logic;
    ExampleBatch_number_last         : in  std_logic;
    ExampleBatch_number_validity     : in  std_logic;
    ExampleBatch_number              : in  std_logic_vector(63 downto 0);
    ExampleBatch_number_unl_valid    : in  std_logic;
    ExampleBatch_number_unl_ready    : out std_logic;
    ExampleBatch_number_unl_tag      : in  std_logic_vector(TAG_WIDTH-1 downto 0);
    ExampleBatch_number_cmd_valid    : out std_logic;
    ExampleBatch_number_cmd_ready    : in  std_logic;
    ExampleBatch_number_cmd_firstIdx : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    ExampleBatch_number_cmd_lastIdx  : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    ExampleBatch_number_cmd_tag      : out std_logic_vector(TAG_WIDTH-1 downto 0);
    start                            : in  std_logic;
    stop                             : in  std_logic;
    reset                            : in  std_logic;
    idle                             : out std_logic;
    busy                             : out std_logic;
    done                             : out std_logic;
    result                           : out std_logic_vector(63 downto 0);
    ExampleBatch_firstidx            : in  std_logic_vector(31 downto 0);
    ExampleBatch_lastidx             : in  std_logic_vector(31 downto 0)
  );
end entity;

architecture Implementation of Sum is

  -- Enumeration type for our state machine.
  type state_t is (STATE_IDLE,
                   STATE_COMMAND,
                   STATE_CALCULATING,
                   STATE_UNLOCK,
                   STATE_DONE);

  -- Current state register and next state signal.
	signal state, state_next : state_t;

  -- Accumulate the total sum here
  signal accumulator, accumulator_next : signed(63 downto 0);

begin

  ------------------------------------------------------------------------------
  -- Sum implementation
  ------------------------------------------------------------------------------

  -- Put the accumulator value on the result register.
  result <= std_logic_vector(accumulator);

  -- We apply a two-process method coding style. That means we split up our
  -- whole circuit in a combinatorial part (logic) and a sequential part
  -- (registers).

  -- Combinatorial part:
  combinatorial_proc : process (all) is
  begin

    -- We first determine the default outputs of our combinatorial circuit.
    -- They may be overwritten by sequential statements within this process
    -- later on.

    -- Make sure the command stream is deasserted by default.
    ExampleBatch_number_cmd_valid    <= '0';
    ExampleBatch_number_cmd_firstIdx <= (others => '0');
    ExampleBatch_number_cmd_lastIdx  <= (others => '0');
    ExampleBatch_number_cmd_tag      <= (others => '0');

    ExampleBatch_number_unl_ready <= '0'; -- Do not accept "unlocks".
    accumulator_next <= accumulator;      -- Retain accumulator value.
    state_next <= state;                  -- Retain current state.

    -- For every state, we will determine the outputs of our combinatorial
    -- circuit.
    case state is
      when STATE_IDLE =>
        -- Idle: We just wait for the start bit to come up.
        done <= '0';
        busy <= '0';
        idle <= '1';

        -- Wait for the start signal (typically controlled by the host-side
        -- software).
        if start = '1' then
          state_next <= STATE_COMMAND;
        end if;
        accumulator_next <= (others => '0');

      when STATE_COMMAND =>
        -- Command: we send a command to the generated interface.
        done <= '0';
        busy <= '1';
        idle <= '0';

        -- The command is a stream, so we assert its valid bit and wait in this
        -- state until it is accepted by the generated interface. If the valid
        -- and ready bit are both asserted in the same cycle, the command is
        -- accepted.
        -- We need to supply a command to the generated interface for each
        -- Arrow field. In the case of this kernel, that means we just have to
        -- generate a single command. The command is sent on the command stream
        -- to the generated interface.
        -- The command includes a range of rows from the recordbatch we want to
        -- work on. In this simple example, we just want this kernel to work on
        -- all the rows in the RecordBatch.
        -- The starting row and ending row (exclusive) that this kernel should
        -- work on is supplied via MMIO and appears on the firstIdx and lastIdx
        -- ports.
        -- We can use the tag field of the command stream to identify different
        -- commands. We don't really use it for this example, so we just set it
        -- to zero.
        ExampleBatch_number_cmd_valid    <= '1';
        ExampleBatch_number_cmd_firstIdx <= ExampleBatch_firstIdx;
        ExampleBatch_number_cmd_lastIdx  <= ExampleBatch_lastIdx;
        ExampleBatch_number_cmd_tag      <= (others => '0');

        if ExampleBatch_number_cmd_ready = '1' then
          state_next <= STATE_CALCULATING;
        end if;

      when STATE_CALCULATING =>
        -- Calculating: we stream in and accumulate the numbers one by one.
        done <= '0';
        busy <= '1';
        idle <= '0';

        -- In this state, we are always ready to process input from the "number"
        -- stream. We don't have to generate backpressure to the generated
        -- interface. The addition can be performed in one cycle.
        ExampleBatch_number_ready <= '1';

        -- When the generated interface has valid data for us on our "number"
        -- stream, we just add the input to whatever the accumulator currently
        -- holds and throw that on the output of this combinatorial circuit.
        if ExampleBatch_number_valid = '1' then
          accumulator_next <= accumulator + signed(ExampleBatch_number);

          -- All we have to do now is check if the last number was supplied.
          -- If that is the case, we can go to the "done" state.
          if ExampleBatch_number_last = '1' then
            state_next <= STATE_UNLOCK;
          end if;
        end if;

      when STATE_UNLOCK =>
        -- Unlock: the generated interface delivered all items in the stream.
        -- The unlock stream is supplied to make sure all bus transfers of the
        -- corresponding command are completed.
        done <= '1';
        busy <= '0';
        idle <= '1';

        -- Ready to handshake the unlock stream:
        ExampleBatch_number_unl_ready <= '1';
        -- Handshake when it is valid and go to the done state.
        if ExampleBatch_number_unl_valid = '1' then
          state_next <= STATE_DONE;
        end if;

      when STATE_DONE =>
        -- Done: the kernel is done with its job.
        done <= '1';
        busy <= '0';
        idle <= '1';

        -- Wait for the reset signal (typically controlled by the host-side
        -- software), so we can go to idle again. This reset is not to be
        -- confused with the system-wide reset that travels into the kernel
        -- alongside the clock (kcd_reset).
        if reset = '1' then
          state_next <= STATE_IDLE;
        end if;

    end case;
  end process;


 -- Sequential part:
  sequential_proc: process (kcd_clk)
  begin
    -- On the rising edge of the kernel clock:
    if rising_edge(kcd_clk) then
      -- Register the next state.
      state <= state_next;
      -- Register the next accumulator value.
      accumulator <= accumulator_next;

      -- If there is a (synchronous) reset, go to idle and make the
      -- accumulator hold zero.
      if kcd_reset = '1' then
        state <= STATE_IDLE;
        accumulator <= (others => '0');
      end if;
    end if;
  end process;

end architecture;

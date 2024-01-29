--
-- This module is an interface that makes it possible to control elements of the architecture
-- using a 16 bit address/data structure. It is also able to handle 8 bit stream data.
-- The interface is SLOW, but it is intented for serial communication interfaces, so it might
-- not be too much of a problem.
--
-- On this design, "master" refers to the computer that sends instructions, "local bus"
-- refers to modules in the FPGA that are accessed by the master.
--
-- TODO : add instructions for 32bit data (6 instructions)
--        add masking instructions (bit set / bit clear / bit toggle) +3 instruction (16bits) / +3 more instructions in 32bits
--        add feature bits and optionnal instructions (16bits set, 32bits set, map, fifo, packet, mask ...
--        add interrupt / letterboxes
--        add possibility to retrieve : clock frequency, FIFO size, function set, ...
--        add write/read instruction to make ? (might be useful for fast filter debug)
----------------------------------------------------------------------------------
--
-- instruction decoding :
--  0x00                                                  : NOP          : resp     ACKshort
--  0x10                                                  : READ_IFVER   : resp     ACKsingle
--  0x20                                                  : READ_PROJID  : resp     ACKsingle
--  0x30                                                  : ERR_CLR      : resp     ACKshort
--  0x40   addrMSB addrLSB                                : read single  : resp (1) ACKsingle
--  0x50   addrMSB addrLSB lenMSB  lenLSB                 : read map     : resp (2) ACKstreamStart + ACKstreamEnd
--  0x60   addrMSB addrLSB lenMSB  lenLSB                 : read FIFO    : resp (2) ACKstreamStart + ACKstreamEnd
--  0x80   addrMSB addrLSB dataMSB dataLSB                : write single : resp (1) ACKshort
--  0x90   addrMSB addrLSB lenMSB  lenLSB  <len x data16> : write map    : resp (2) ACKshort       + ACKstreamEnd
--  0xA0   addrMSB addrLSB lenMSB  lenLSB  <len x data16> : write FIFO   : resp (2) ACKshort       + ACKstreamEnd
--  0xC0   addr            lenMSB  lenLSB  <len x data8>  : packet exc   : resp (2) ACKstreamStart + ACKstreamEnd
--  0xD0   addr            lenMSB  lenLSB                 : packet read  : resp (2) ACKstreamStart + ACKstreamEnd
--  0xE0   addr            lenMSB  lenLSB  <len x data8>  : packet write : resp (2) ACKshort       + ACKstreamEnd
--  0xF0                                                  : Invalid op   : resp (1) ACKInvalidInstruction (internal use)
--  others                                                : reserved     : resp (1) ACKInvalidInstruction 
--
-- (1) : in case of address or timeout error, response will be ACKAddressError or ACKtimeout
-- (2) : in case of address or timeout error on the first data word, response will be ACKAddressError or ACKtimeout, if
--       the error occurs in the remaining data, the corresponding bit will be set in ACKstreamEnd, if writing, data after
--       the error is discarded, if reading, data after the error has no meaning. If size is 0, an ACKNullSize response is sent
--
--
--
--
-- response decoding :
--  bit 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 : followed by 
--      0   0   0   0   0   0   0   0 : -               : Nothing to say
--      0   0   0   1   -   -   -   - : -               : Reserved
--      0   0   1   0   -   -   -   f : -               : ACKAddressError
--      0   0   1   1   -   -   -   f : -               : ACKNullSize
--      0   1   0   -   -   -   -   f : -               : ACKInvalidInstruction
--      0   1   1   -   -   -   -   f : -               : ACKshort
--      1   0   0   -   -   -   -   f : dataMSB dataLSB : ACKsingle
--      1   0   1   -   -   -   -   f : -               : ACKtimeout
--      1   1   0   -   -   -   -   f : len x data      : ACKstreamStart
--      1   1   1   -   -   t   a   f : lenMSB  lenLSB  : ACKstreamEnd (data correctly processed)
--
--     a : 1 = address error      (peripheral returned invalid address during MAP operation) / timeout on write for packet exc
--     f : 1 = fifo full error    (FIFO full bit was activated)
--     t : 1 = timeout error      (No peripheral responded in time) / imeout in read for packet exc
----------------------------------------------------------------------------------
--
--  address, Fifo and timeout error flags are cleared for each new instruction
--  Unexpected state error is only cleared on reset
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity computer_IF is
    Generic ( PROJECT_ID    : STD_LOGIC_VECTOR(15 downto 0) :=(others => '0');  -- used to identify architecture in a standard way
	          TIMEOUT       : INTEGER := 100000);             -- peripheral ACK timeout in clock periods

    Port (  clk       : in  STD_LOGIC;                         -- system clock
            reset     : in  STD_LOGIC;                         -- system reset (active high)
            RXdat     : in  STD_LOGIC_VECTOR( 7 downto 0);     -- master input data
            RXen      : in  STD_LOGIC;                         -- master input data strobe
            RXrdy     : out STD_LOGIC;                         -- master input data ready
            TXdat     : out STD_LOGIC_VECTOR( 7 downto 0);     -- master output data
            TXen      : out STD_LOGIC;                         -- master output data strobe
            TXrdy     : in  STD_LOGIC := '1';                  -- master output data redy
            lst_CMD_b : out STD_LOGIC;                         -- set when expecting last instruction byte, cleared otherwise FIXME : need to clarify behavior

            addr      : out STD_LOGIC_VECTOR(15 downto 0);     -- local data address
            dout      : out STD_LOGIC_VECTOR(15 downto 0);     -- data to be written locally
            din       : in  STD_LOGIC_VECTOR(15 downto 0);     -- local data to be responded

            d_wen     : out STD_LOGIC;                         -- local data write enable
            d_wack    : in  STD_LOGIC := '1';                  -- local data write ack
            d_ren     : out STD_LOGIC;                         -- local data read enable
            d_rack    : in  STD_LOGIC := '1';                  -- local data read ack

            p_empty_n : out STD_LOGIC;                         -- stream packet data available for write to system
            p_read    : in  STD_LOGIC := '1';                  -- stream packet data write ack from system
            p_full_n  : out STD_LOGIC;                         -- stream packet room available for read from system
            p_write   : in  STD_LOGIC := '1';                  -- stream packet data read from system
            p_start   : out STD_LOGIC;                         -- packet start event (address is valid) 
            p_stop    : out STD_LOGIC;                         -- packet stop event

            err_mstmx : in  STD_LOGIC := '0';                  -- set to trigger a fifo full error to master
            err_addr  : in  STD_LOGIC := '0');                 -- set to trigger an invalid address error
end computer_IF;

architecture Behavioral of computer_IF is

    constant MODULE_VERSION   : std_logic_vector(15 downto 0) := x"0000";

    constant opcode_NOP       : std_logic_vector( 7 downto 0) := x"00"; -- No Operation, necessary when master lost sync with FSM
    constant opcode_RD_IFVER  : std_logic_vector( 7 downto 0) := x"10"; -- read interface version given by MODULE_VERSION constant
    constant opcode_RD_PROJID : std_logic_vector( 7 downto 0) := x"20"; -- read project identification, given by PROJECT_ID generic
    constant opcode_ERR_CLR   : std_logic_vector( 7 downto 0) := x"30"; -- error clear : resets all error flags
    constant opcode_RD_SINGLE : std_logic_vector( 7 downto 0) := x"40"; -- read single 16bit data at 16bit address
    constant opcode_RD_MAP    : std_logic_vector( 7 downto 0) := x"50"; -- read block of 16bit data, starting at 16bit address (address is incremented)
    constant opcode_RD_FIFO   : std_logic_vector( 7 downto 0) := x"60"; -- read 16bit data successively at given address (address is not incremented)
    constant opcode_WR_SINGLE : std_logic_vector( 7 downto 0) := x"80"; -- write single 16bit data at 16bit address
    constant opcode_WR_MAP    : std_logic_vector( 7 downto 0) := x"90"; -- write block of 16bit data, starting at 16bit address (address is incremented)
    constant opcode_WR_FIFO   : std_logic_vector( 7 downto 0) := x"A0"; -- write 16bit data successively at given address (address is not incremented)
    constant opcode_PCKT_EXC  : std_logic_vector( 7 downto 0) := x"C0"; -- 8bit data packet exchange at given stream identified by 8bit address
    constant opcode_PCKT_RD   : std_logic_vector( 7 downto 0) := x"D0"; -- 8bit data packet read at given stream identified by 8bit address
    constant opcode_PCKT_WR   : std_logic_vector( 7 downto 0) := x"E0"; -- 8bit data packet write at given stream identified by 8bit address




    type instr_decoder_t is (exp_cmd,                -- no command pending, next char received should be a command number
                             exp_16b_addr_MSB,       -- just received a command, expecting start of 16bit address
                             exp_16b_addr_LSB,       -- just received an address MSB, expecting address LSB
                             exp_8b_addr,            -- expecting an 8 bit address, most likely after a 0xC0 command
                             exp_first_16b_data_MSB, -- expecting the MSB of the first 16bit data
                             exp_first_16b_data_LSB, -- just received the MSB of the first 16bit data, expecting the LSB
                             exp_len_MSB,            -- expecting the MSB of a 16bit data length
                             exp_len_LSB,            -- expecting the LSB of a 16bit data length
                             exp_first_8b_data,      -- expecting the first 8bit data, most likely for the 0xC0 command
                             exp_rem_16b_data_MSB,   -- expecting the MSB of a remaining 16bit data
                             exp_rem_16b_data_LSB,   -- just received the MSB of a remaining 16bit data, expecting the LSB
                             exp_rem_8b_data,        -- expecting a remaining 8bit data, most likely for the 0xC0 command

                             exp_slave_f16b_wACK,    -- expecting first write ack for 16b data from slave
                             exp_slave_f16b_data,    -- expecting first read response for 16b data from slave
                             exp_slave_f8b_wACK,     -- expecting first write ack for 8b data from slave
                             exp_slave_f8b_data,     -- expecting first read response for 8b data from slave

                             exp_slave_r16b_wACK,    -- expecting remaining write ack for 16b data from slave
                             exp_slave_r16b_data,    -- expecting remaining read response for 16b data from slave
                             exp_slave_r8b_data,     -- expecting remaining read response for 8b data from slave
                             exp_slave_r8b_wACK,     -- expecting remaining write ack for 8b data from slave
                             
                             wait_master_1st_ACK_rd, -- waiting for master to read (eventually first) ACK
                             wait_master_end_ACK_rd, -- waiting for master to read (eventually first) ACK
                             wait_master_MSB_rd,     -- waiting for master to read while 16bits MSB data
                             wait_master_LSB_rd,     -- waiting for master to read while 16bits MSB data
                             wait_master_8b_rd,      -- waiting for master to read while 8bits pending in buffer
                             wait_master_lenMSB_rd,  -- waiting for master to read data length MSB
                             wait_master_lenLSB_rd,  -- waiting for master to read data length LSB
                             
                             unexpected_state);      -- this state should NEVER happen !!!
    signal instr_decoder : instr_decoder_t;       -- the signal that contains the current state

    --signal err_FSMstate           : std_logic;                     -- status bit concerning instruction validity
    signal err_timeout            : std_logic;                     -- status bit concerning timeout response
    signal err_address            : std_logic;                     -- status bit concerning invalid address
    signal err_fifo               : std_logic;                     -- status bit concerning FIFO full error
    signal err_nullsize           : std_logic;                     -- status bit concerning FIFO full error


    signal curr_instruction       : std_logic_vector( 7 downto 0); -- the instruction being processed;
                                                                   -- should be more efficient if implemented as enumerated...
    signal rem_data_xfer          : integer range 0 to (2**16)-1;  -- remaining data words to tran from master - 1
    signal buffered_addr          : std_logic_vector(15 downto 0); -- local copy of addr to allow incrementation
    signal data_xfer_ok           : integer range 0 to (2**16)-1;  -- data words that have been transferd before first error
    signal data_xfer_counting     : boolean;                       -- should we still count data ?


    signal RXrdyi                 : std_logic;                     -- local copy of RXrdy for internal use
    signal TXeni                  : std_logic;                     -- local copy of TXen  for internal use
    signal d_weni                 : std_logic;                     -- local copy of d_wen for internal use
    signal d_reni                 : std_logic;                     -- local copy of d_ren for internal use
    signal p_empty_ni             : std_logic;                     -- local copy of d_wen for internal use
    signal p_full_ni              : std_logic;                     -- local copy of d_ren for internal use

    signal data_buffer            : std_logic_vector(15 downto 0); -- the signal in which we store data to send to master 
    signal timeout_cnt            : integer range 0 to TIMEOUT;    -- the counter to check for slave timeout


    signal ACKInvalidInstruction  : std_logic_vector(7 downto 0); -- the message sent for ACKInvalidInstruction
    signal ACKshort               : std_logic_vector(7 downto 0); -- the message sent for ACKshort
    signal ACKsingle              : std_logic_vector(7 downto 0); -- the message sent for ACKsingle
    signal ACKtimeout             : std_logic_vector(7 downto 0); -- the message sent for ACKtimeout
    signal ACKstreamStart         : std_logic_vector(7 downto 0); -- the message sent for ACKstreamsSart
    signal ACKstreamEnd           : std_logic_vector(7 downto 0); -- the message sent for ACKstreamsEnd
    signal ACKAddressError        : std_logic_vector(7 downto 0); -- the message sent for ACKAddressError
    signal ACKNullSize            : std_logic_vector(7 downto 0); -- the message sent for ACKNullSize
    
    





begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                instr_decoder <= exp_cmd;
            else
                case instr_decoder is
                    ------------------------------------------------------------------------
                    -- In this set of states, we are waiting for data coming from master
                    ------------------------------------------------------------------------ 
                    when exp_cmd          =>
                        if RXen = '1' and RXrdyi = '1' then
            			    case RXdat is
                                when opcode_RD_SINGLE | opcode_RD_MAP | opcode_RD_FIFO | opcode_WR_SINGLE | opcode_WR_MAP | opcode_WR_FIFO =>
                                    instr_decoder <= exp_16b_addr_MSB;
                                when opcode_PCKT_EXC  | opcode_PCKT_RD | opcode_PCKT_WR =>
                                    instr_decoder <= exp_8b_addr;
                            --    when opcode_NOP | opcode_ERR_CLR | opcode_RD_IFVER | opcode_RD_PROJID => 
                            --        instr_decoder <= wait_master_1st_ACK_rd;
                                when others =>
            					    instr_decoder <= wait_master_1st_ACK_rd;
                            end case;
                        end if;
                    when exp_16b_addr_MSB =>
                        if RXen = '1' and RXrdyi = '1' then
                            instr_decoder <= exp_16b_addr_LSB;
                        end if;
                    when exp_16b_addr_LSB =>
                        if RXen = '1' and RXrdyi = '1' then
                            case curr_instruction is
                                when opcode_WR_SINGLE =>
                                    instr_decoder <= exp_first_16b_data_MSB;
                                when opcode_RD_SINGLE =>
                                    instr_decoder <= exp_slave_f16b_data;
                                when opcode_RD_MAP | opcode_RD_FIFO | opcode_WR_MAP | opcode_WR_FIFO =>
                                    instr_decoder <= exp_len_MSB;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;
                    when exp_8b_addr      =>
                        if RXen = '1' and RXrdyi = '1' then
                            instr_decoder <= exp_len_MSB;
                        end if;
                    when exp_first_16b_data_MSB =>
                        if RXen = '1' and RXrdyi = '1' then
                            instr_decoder <= exp_first_16b_data_LSB;
                        end if;
                    when exp_first_16b_data_LSB =>
                        if RXen = '1' and RXrdyi = '1' then
                            case curr_instruction is
                                when opcode_WR_SINGLE | opcode_WR_MAP | opcode_WR_FIFO =>
                                    instr_decoder <= exp_slave_f16b_wACK;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;
                    when exp_len_MSB      =>
                        if RXen = '1' and RXrdyi = '1' then
                            instr_decoder <= exp_len_LSB;
                        end if;
                    when exp_len_LSB      =>
                        if RXen = '1' and RXrdyi = '1' then
                            if (rem_data_xfer mod 256)= 0 and RXdat = x"00" then
                                instr_decoder <= wait_master_1st_ACK_rd;
                            else
                			    case curr_instruction is
                                    when opcode_RD_MAP   | opcode_RD_FIFO =>
                                        instr_decoder <= exp_slave_f16b_data;
                                    when opcode_WR_MAP   | opcode_WR_FIFO =>
                                        instr_decoder <= exp_first_16b_data_MSB;
                                    when opcode_PCKT_EXC | opcode_PCKT_WR =>
                                        instr_decoder <= exp_first_8b_data;
                                    when opcode_PCKT_RD =>
                                        instr_decoder <= exp_slave_f8b_data;
                                    when others =>
                                        instr_decoder <= unexpected_state;
                                end case;
                            end if;
                        end if;
                    when exp_first_8b_data =>
                        if RXen = '1' and RXrdyi = '1' then
                            case curr_instruction is
                                when opcode_PCKT_EXC=>
                                    instr_decoder <= exp_slave_f8b_wACK; -- TODO simplify this statement
                                when opcode_PCKT_WR =>
                                    instr_decoder <= exp_slave_f8b_wACK;
                                when others         =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;
                    when exp_rem_16b_data_MSB =>
                        if RXen = '1' and RXrdyi = '1' then
                            instr_decoder <= exp_rem_16b_data_LSB;
                        end if;
                    when exp_rem_16b_data_LSB =>
                        if RXen = '1' and RXrdyi = '1' then
                            if (err_address or err_timeout) = '1' then
                                if rem_data_xfer < 2 then
                                    instr_decoder <= wait_master_end_ACK_rd;
                                else
                                    instr_decoder <= exp_rem_16b_data_MSB;
                                end if;
                            else
                                instr_decoder <= exp_slave_r16b_wACK;
                            end if;
                        end if;
                    when exp_rem_8b_data =>
                        if RXen = '1' and RXrdyi = '1' then
            			    case curr_instruction is
                                when opcode_PCKT_EXC=>
                                    if (err_address or err_timeout) = '1' then
                                        instr_decoder <= wait_master_8b_rd;
                                    else
                                        instr_decoder <= exp_slave_r8b_wACK;
                                    end if;
                                when opcode_PCKT_WR  =>
                                    if (err_address or err_timeout) = '1' then
                                        if rem_data_xfer < 2 then
                                            instr_decoder <= wait_master_end_ACK_rd;
                                        else
                                            instr_decoder <= exp_rem_8b_data;
                                        end if;
                                    else
                                        instr_decoder <= exp_slave_r8b_wACK;
                                    end if;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;

                    ------------------------------------------------------------------------
                    -- In this set of states, we are waiting for activity from slave
                    ------------------------------------------------------------------------                     
                    when exp_slave_f16b_wACK =>
                        if d_wack = '1' or err_addr='1' or err_timeout='1' then
                            case curr_instruction is
                                when opcode_WR_SINGLE | opcode_WR_MAP | opcode_WR_FIFO =>
                                    instr_decoder <= wait_master_1st_ACK_rd;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;
                        
                    when exp_slave_f16b_data =>
                        if d_rack = '1' or err_addr='1' or err_timeout='1' then
                            case curr_instruction is
                                when opcode_RD_SINGLE | opcode_RD_MAP | opcode_RD_FIFO =>
                                    instr_decoder <= wait_master_1st_ACK_rd;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;

                    when exp_slave_f8b_wACK =>
                        if p_read = '1' or err_addr='1' or err_timeout='1' then
                            case curr_instruction is
                                when opcode_PCKT_WR | opcode_PCKT_EXC =>
                                    instr_decoder <= wait_master_1st_ACK_rd;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;
                        
                    when exp_slave_f8b_data =>
                        if p_write = '1' or err_addr='1' or err_timeout='1' then
                            case curr_instruction is
                                when opcode_PCKT_RD =>
                                    instr_decoder <= wait_master_1st_ACK_rd;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;

                    when exp_slave_r16b_wACK =>
                        if d_wack = '1' or err_addr='1' or err_timeout='1' then                                
                            case curr_instruction is
                                when opcode_WR_MAP | opcode_WR_FIFO =>
                                    if rem_data_xfer = 0 then
                                        instr_decoder <= wait_master_end_ACK_rd;
                                    else
                                        instr_decoder <= exp_rem_16b_data_MSB;                                        
                                    end if;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;
                        
                    when exp_slave_r16b_data =>
                        if d_rack = '1' or err_addr='1' or err_timeout='1' then
                            case curr_instruction is
                                when opcode_RD_MAP | opcode_RD_FIFO =>
                                    instr_decoder <= wait_master_MSB_rd;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;

                    when exp_slave_r8b_wACK =>
                        if p_read = '1' or err_address='1' or err_addr = '1' or err_timeout='1' then
                            case curr_instruction is
                                when opcode_PCKT_WR =>
                                    if rem_data_xfer = 0 then
                                        instr_decoder <= wait_master_end_ACK_rd;
                                    else
                                        instr_decoder <= exp_rem_8b_data;                                        
                                    end if;
                                when opcode_PCKT_EXC =>
                                    if p_read = '1' then
                                        instr_decoder <= exp_slave_r8b_data;                                        
                                    else
                                        instr_decoder <= wait_master_8b_rd;                                                                                
                                    end if;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;
                        
                    when exp_slave_r8b_data =>
                        if p_write = '1' or err_addr='1' or err_timeout='1' then
                            case curr_instruction is
                                when opcode_PCKT_RD | opcode_PCKT_EXC =>
                                    instr_decoder <= wait_master_8b_rd;                                        
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;

                    ------------------------------------------------------------------------
                    -- In this set of states, we are waiting for master to read a response
                    ------------------------------------------------------------------------                     
                    
                    when wait_master_1st_ACK_rd => 
                        if TXeni = '1' and TXrdy = '1' then
                            case curr_instruction is
                                when opcode_NOP | opcode_ERR_CLR | opcode_WR_SINGLE =>
                                    instr_decoder <= exp_cmd;
                                when opcode_RD_IFVER | opcode_RD_PROJID =>
                                    instr_decoder <= wait_master_MSB_rd;
                                when opcode_RD_SINGLE =>
                                    if (err_address or err_timeout) = '1' then
                                        instr_decoder <= exp_cmd;
                                    else
                                        instr_decoder <= wait_master_MSB_rd;
                                    end if;
                                when opcode_RD_MAP | opcode_RD_FIFO =>
                                    if (err_address or err_timeout or err_nullsize) = '1' then
                                        instr_decoder <= exp_cmd;
                                    else
                                        instr_decoder <= wait_master_MSB_rd;
                                    end if;
                                when opcode_WR_MAP | opcode_WR_FIFO =>
                                    if (err_address  or err_timeout or err_nullsize) = '1' then
                                        instr_decoder <= exp_cmd;
                                    elsif rem_data_xfer = 0 then
                                        instr_decoder <= wait_master_end_ACK_rd;
                                    else
                                        instr_decoder <= exp_rem_16b_data_MSB;
                                    end if;
                                when opcode_PCKT_EXC =>
                                    if (err_address  or err_timeout or err_nullsize) = '1' then
                                        instr_decoder <= exp_cmd;
                                    else
                                        instr_decoder <= exp_slave_r8b_data;
                                    end if;
                                when opcode_PCKT_RD =>
                                    if (err_address  or err_timeout or err_nullsize) = '1' then
                                        instr_decoder <= exp_cmd;
                                    else
                                        instr_decoder <= wait_master_8b_rd;
                                    end if;
                                when opcode_PCKT_WR =>
                                    if (err_address  or err_timeout or err_nullsize) = '1' then
                                        instr_decoder <= exp_cmd;
                                    elsif rem_data_xfer = 0 then
                                        instr_decoder <= wait_master_end_ACK_rd;
                                    else
                                        instr_decoder <= exp_rem_8b_data;
                                    end if;
                                when others =>
                                    instr_decoder <= exp_cmd;
                            end case;
                        end if;
                    
                    when wait_master_end_ACK_rd => 
                        if TXeni = '1' and TXrdy = '1' then
                            case curr_instruction is
                                when opcode_RD_MAP | opcode_RD_FIFO | opcode_WR_MAP | opcode_WR_FIFO | opcode_PCKT_EXC | opcode_PCKT_RD | opcode_PCKT_WR =>
                                    instr_decoder <= wait_master_lenMSB_rd;
                                when others =>
                                    instr_decoder <= unexpected_state;
                            end case;
                        end if;

                    when wait_master_MSB_rd => 
                        if TXeni = '1' and TXrdy = '1' then
                            instr_decoder <= wait_master_LSB_rd;
                        end if;

                    when wait_master_LSB_rd => 
                        if TXeni = '1' and TXrdy = '1' then
                            case curr_instruction is
                                when opcode_RD_IFVER | opcode_RD_PROJID | opcode_RD_SINGLE =>
                                    instr_decoder <= exp_cmd;
                                when opcode_RD_MAP | opcode_RD_FIFO =>
                                    if rem_data_xfer < 2 then
                                        instr_decoder <= wait_master_end_ACK_rd;
                                    elsif (err_address or err_timeout) = '1' then
                                        instr_decoder <= wait_master_MSB_rd;
                                    else
                                        instr_decoder <= exp_slave_r16b_data;
                                    end if;
                                when others =>
                                    instr_decoder <= exp_cmd;
                            end case;
                        end if;

                    when wait_master_8b_rd => 
                        if TXeni = '1' and TXrdy = '1' then
                            case curr_instruction is
                                when opcode_PCKT_EXC =>
                                    if rem_data_xfer < 2 then
                                        instr_decoder <= wait_master_end_ACK_rd;
                                    else
                                        instr_decoder <= exp_rem_8b_data;
                                    end if;
                                when opcode_PCKT_RD =>
                                    if rem_data_xfer < 2 then
                                        instr_decoder <= wait_master_end_ACK_rd;
                                    elsif (err_address or err_timeout) = '1' then
                                        instr_decoder <= wait_master_8b_rd;
                                    else
                                        instr_decoder <= exp_slave_r8b_data;
                                    end if;
                                when others =>
                                    instr_decoder <= exp_cmd;
                            end case;
                        end if;

                    when wait_master_lenMSB_rd => 
                        if TXeni = '1' and TXrdy = '1' then
                            instr_decoder <= wait_master_lenLSB_rd;
                        end if;

                    when wait_master_lenLSB_rd => 
                        if TXeni = '1' and TXrdy = '1' then
                            instr_decoder <= exp_cmd;
                        end if;

                    when unexpected_state =>
                        instr_decoder <= exp_cmd;
                end case;
            end if;
        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                curr_instruction <= opcode_NOP;
	    elsif RXen = '1' and RXrdyi = '1' and instr_decoder = exp_cmd then
                curr_instruction <= RXdat;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            case instr_decoder is
                when exp_cmd =>
                    rem_data_xfer <= 1;
                when exp_len_MSB =>
                    rem_data_xfer <= to_integer(unsigned(RXdat));
                when exp_len_LSB =>
                    if RXen = '1' and RXrdyi = '1' then
                        rem_data_xfer <= rem_data_xfer*256 + to_integer(unsigned(RXdat));
                    end if;
                when wait_master_8b_rd =>   -- for PCKT_EXC and PCKT_RD
                    if TXeni = '1' and TXrdy = '1' and rem_data_xfer > 0 then
                        rem_data_xfer <= rem_data_xfer - 1;
                    end if;
--                when exp_slave_r8b_wACK | exp_slave_f8b_wACK =>   -- for PCKT_WR only
--                    if curr_instruction = opcode_PCKT_WR and (p_read = '1' or err_addr='1' or err_timeout='1') then
--                        rem_data_xfer <= rem_data_xfer - 1;
--                    end if;
                when exp_rem_8b_data | exp_first_8b_data  =>  -- for PCKT_WR only
                    if RXen = '1' and RXrdyi = '1' and curr_instruction = opcode_PCKT_WR then
                        rem_data_xfer <= rem_data_xfer - 1;
                    end if;

--                when exp_slave_r16b_wACK | exp_slave_f16b_wACK =>  -- for WR_SINGLE (with no effect), WR_MAP, WR_FIFO 
--                    if d_wack = '1' or err_addr='1' or err_timeout='1' then
--                        rem_data_xfer <= rem_data_xfer - 1;
--                    end if;

                when exp_rem_16b_data_LSB | exp_first_16b_data_LSB => 
                    if RXen = '1' and RXrdyi = '1' then
                        rem_data_xfer <= rem_data_xfer - 1;
                    end if;
--                when exp_slave_r16b_data | exp_slave_f16b_data =>  -- for RD_SINGLE (with no effect), RD_MAP, RD_FIFO 
--                    if d_rack = '1' or err_addr='1' or err_timeout='1' then
--                        rem_data_xfer <= rem_data_xfer - 1;
--                    end if;
                when wait_master_LSB_rd => 
                    if TXeni = '1' and TXrdy = '1' then
                        rem_data_xfer <= rem_data_xfer - 1;
                    end if;
                when others =>
                    null;
            end case;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                lst_CMD_b <= '1';
            else
                if instr_decoder = wait_master_1st_ACK_rd then
                    case curr_instruction is
                        when opcode_RD_IFVER | opcode_RD_PROJID =>
                            lst_CMD_b <= '0';
                        when opcode_RD_SINGLE =>
                            if TXrdy = '1' and TXeni = '1' then
                                lst_CMD_b <= '0';
                            else
                                lst_CMD_b <= err_address or err_timeout;
                            end if;
                        when opcode_RD_MAP | opcode_RD_FIFO | opcode_WR_MAP | opcode_WR_FIFO | opcode_PCKT_EXC | opcode_PCKT_RD | opcode_PCKT_WR =>
                            if TXrdy = '1' and TXeni = '1' then
                                lst_CMD_b <= '0';
                            elsif err_nullsize = '1' then
                                lst_CMD_b <= '1';
                            else
                                lst_CMD_b <= err_address or err_timeout;
                            end if;
                        when others =>
                            if TXrdy = '1' and TXeni = '1' then
                                lst_CMD_b <= '0';
                            else
                                lst_CMD_b <= '1';
                            end if;
                    end case;
                elsif instr_decoder = wait_master_LSB_rd then
                    case curr_instruction is
                        when opcode_RD_IFVER | opcode_RD_PROJID | opcode_RD_SINGLE =>
                            if TXrdy = '1' and TXeni = '1' then
                                lst_CMD_b <= '0';
                            else
                                lst_CMD_b <= '1';
                            end if;
                        when others =>
                            lst_CMD_b <= '0';                        
                    end case;
                elsif instr_decoder = wait_master_lenLSB_rd then
                    if TXrdy = '1' and TXeni = '1' then
                        lst_CMD_b <= '0';
                    else
                        lst_CMD_b <= '1';
                    end if;
                else
                    lst_CMD_b <= '0';
                end if;
            end if;
        end if;
    end process;




    addr <= buffered_addr;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                buffered_addr <= x"0000";
    	    elsif RXen = '1' and RXrdyi = '1' and instr_decoder = exp_16b_addr_MSB then
        		buffered_addr(15 downto 8) <= RXdat;
    	    elsif RXen = '1' and RXrdyi = '1' and instr_decoder = exp_16b_addr_LSB then
        		buffered_addr( 7 downto 0) <= RXdat;
    	    elsif RXen = '1' and RXrdyi = '1' and instr_decoder = exp_8b_addr then
        		buffered_addr( 7 downto 0) <= RXdat;
    	    elsif RXen = '1' and RXrdyi = '1' and instr_decoder = exp_rem_16b_data_MSB and curr_instruction = opcode_WR_MAP then
                buffered_addr <= std_logic_vector(unsigned(buffered_addr) + 1);
    	    elsif TXeni = '1' and TXrdy = '1' and instr_decoder = wait_master_MSB_rd and curr_instruction = opcode_RD_MAP then
                buffered_addr <= std_logic_vector(unsigned(buffered_addr) + 1);
            end if;
        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                dout <= x"0000";
    	    elsif RXen = '1' and RXrdyi = '1' and ((instr_decoder = exp_first_16b_data_MSB) or (instr_decoder = exp_rem_16b_data_MSB)) then
                dout(15 downto 8) <= RXdat;
    	    elsif RXen = '1' and RXrdyi = '1' and ((instr_decoder = exp_first_16b_data_LSB) or (instr_decoder = exp_rem_16b_data_LSB) or (instr_decoder = exp_first_8b_data) or (instr_decoder = exp_rem_8b_data)) then
        		dout( 7 downto 0) <= RXdat;
            end if;
        end if;
    end process;

    RXrdy  <= RXrdyi;
    process(clk)
    begin
        if rising_edge(clk) then
            if RXen = '1' then
                RXrdyi <= '0';
            else
                case instr_decoder is
                    when exp_cmd | exp_16b_addr_MSB | exp_16b_addr_LSB | exp_8b_addr | exp_first_16b_data_MSB | exp_first_16b_data_LSB |
                         exp_len_MSB | exp_len_LSB | exp_first_8b_data | exp_rem_16b_data_MSB | exp_rem_16b_data_LSB | exp_rem_8b_data =>
                        RXrdyi <= '1';
                    when others =>
                        RXrdyi <= '0';
                end case;
            end if;
        end if;
    end process;

    TXen <= TXeni;
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                TXeni <= '0';
            else
                case instr_decoder is
                    when wait_master_1st_ACK_rd | wait_master_end_ACK_rd | wait_master_MSB_rd | wait_master_LSB_rd | 
                         wait_master_8b_rd | wait_master_lenMSB_rd | wait_master_lenLSB_rd =>
                        if TXrdy = '1' and TXeni = '1' then
                            TXeni <= '0';
                        else 
                            TXeni <= '1';
                        end if;
                    when others =>
                        TXeni <= '0';
                end case;
            end if;
        end if;
    end process;

    ACKAddressError        <= "0010000" & err_fifo;
    ACKNullSize            <= "0011000" & err_fifo;
    ACKInvalidInstruction  <= "0100000" & err_fifo;
    ACKshort               <= "0110000" & err_fifo;
    ACKsingle              <= "1000000" & err_fifo;
    ACKtimeout             <= "1010000" & err_fifo;
    ACKstreamStart         <= "1100000" & err_fifo;
    ACKstreamEnd           <= "11100" & err_timeout & err_address & err_fifo;


    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                TXdat <= x"00";
            else
                case instr_decoder is
                    when wait_master_1st_ACK_rd =>
                        if err_timeout = '1' then
                            TXdat <=ACKtimeout;
                        elsif err_address = '1' then
                            TXdat <=ACKAddressError;
                        elsif err_nullsize = '1' then
                            TXdat <= ACKNullSize;                            
                        else
                            case curr_instruction is
                                when opcode_NOP | opcode_ERR_CLR | opcode_WR_SINGLE =>
                                    TXdat <=ACKshort;
                                when opcode_WR_MAP | opcode_WR_FIFO | opcode_PCKT_WR =>
                                    TXdat <= ACKshort;                                        
                                when opcode_RD_IFVER | opcode_RD_PROJID | opcode_RD_SINGLE =>
                                    TXdat <= ACKsingle;
                                when opcode_RD_MAP | opcode_RD_FIFO | opcode_PCKT_EXC | opcode_PCKT_RD =>
                                    TXdat <= ACKstreamStart;                                        
                                when others =>
                                    TXdat <= ACKInvalidInstruction;
                            end case;
                        end if;
                    when wait_master_end_ACK_rd =>
                        TXdat <= ACKstreamEnd;
                    
                    when wait_master_lenMSB_rd =>
                        TXdat <= std_logic_vector(to_unsigned(data_xfer_ok / 256, 8));
                        
                    when wait_master_lenLSB_rd =>
                        TXdat <= std_logic_vector(to_unsigned(data_xfer_ok mod 256, 8));
                        
                    when wait_master_8b_rd  =>
                        TXdat <= data_buffer( 7 downto 0);

                    when wait_master_MSB_rd =>
                        case curr_instruction is
                            when opcode_RD_IFVER  =>
                                TXdat <= MODULE_VERSION(15 downto 8);
                            when opcode_RD_PROJID =>
                                TXdat <= PROJECT_ID(15 downto 8);
                            when opcode_RD_SINGLE | opcode_RD_MAP | opcode_RD_FIFO =>
                                TXdat <= data_buffer(15 downto 8);
--                            when opcode_PCKT_EXC | opcode_PCKT_RD =>
--                                TXdat <= data_buffer(15 downto 8);
                            when others =>
                                TXdat <= x"00";
                        end case;                    
                    when wait_master_LSB_rd =>
                        case curr_instruction is
                            when opcode_RD_IFVER  =>
                                TXdat <= MODULE_VERSION( 7 downto 0);
                            when opcode_RD_PROJID =>
                                TXdat <= PROJECT_ID( 7 downto 0);
                            when opcode_RD_SINGLE | opcode_RD_MAP | opcode_RD_FIFO =>
                                TXdat <= data_buffer( 7 downto 0);
--                            when opcode_PCKT_EXC | opcode_PCKT_RD =>
--                                TXdat <= data_buffer( 7 downto 0);
                            when others =>
                                TXdat <= x"00";
                        end case;

                    when others =>
                        TXdat <= x"00";                                                      -- Nothing to say
                end case;
            end if;
        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            if instr_decoder = exp_cmd then
                data_xfer_ok       <= 0;
                data_xfer_counting <= True;
            elsif instr_decoder = exp_slave_f16b_wACK or instr_decoder = exp_slave_r16b_wACK then
                if d_wack = '1' and data_xfer_counting then
                    data_xfer_ok       <= data_xfer_ok+1;
                elsif err_addr = '1' or err_timeout = '1' then
                    data_xfer_counting <= False;
                end if;
            elsif instr_decoder = exp_slave_f16b_data or instr_decoder = exp_slave_r16b_data then
                if d_rack = '1' and data_xfer_counting then
                    data_xfer_ok       <= data_xfer_ok+1;
                elsif err_addr = '1' or err_timeout = '1' then
                    data_xfer_counting <= False;
                end if;
            elsif instr_decoder = exp_slave_f8b_wACK or instr_decoder = exp_slave_r8b_wACK then
                if p_read = '1' and data_xfer_counting and curr_instruction = opcode_PCKT_WR then
                    data_xfer_ok       <= data_xfer_ok+1;
                elsif err_addr = '1' or err_timeout = '1' then
                    data_xfer_counting <= False;
                end if;
            elsif instr_decoder = exp_slave_f8b_data or instr_decoder = exp_slave_r8b_data then
                if p_write = '1' and data_xfer_counting then
                    data_xfer_ok       <= data_xfer_ok+1;
                elsif err_addr = '1' or err_timeout = '1' then
                    data_xfer_counting <= False;
                end if;
            end if;
        end if;
    end process;


    d_wen  <= d_weni;
    process(clk)
    begin
        if rising_edge(clk) then
            if d_wack = '1' or err_addr = '1' or err_timeout = '1' then
                d_weni <= '0';
            else
                case instr_decoder is
                    when exp_slave_f16b_wACK | exp_slave_r16b_wACK =>
                        d_weni <= '1';
                    when others =>
                        d_weni <= '0';
                end case;
            end if;
        end if;
    end process;

    d_ren <= d_reni;
    process(clk)
    begin
        if rising_edge(clk) then
            if d_rack = '1' or err_addr = '1' or err_timeout = '1' then
                d_reni <= '0';
            else
                case instr_decoder is
                    when exp_slave_f16b_data | exp_slave_r16b_data =>
                        d_reni <= '1';
                    when others =>
                        d_reni <= '0';
                end case;
            end if;
        end if;
    end process;

    p_empty_n  <= p_empty_ni;
    process(clk)
    begin
        if rising_edge(clk) then
            if p_read = '1' or err_addr = '1' or err_timeout = '1' then
                p_empty_ni <= '0';
            else
                case instr_decoder is
                    when exp_slave_f8b_wACK | exp_slave_r8b_wACK =>
                        p_empty_ni <= '1';
                    when others =>
                        p_empty_ni <= '0';
                end case;
            end if;
        end if;
    end process;

    p_full_n <= p_full_ni;
    process(clk)
    begin
        if rising_edge(clk) then
            if p_write = '1' or err_addr = '1' or err_timeout = '1' then
                p_full_ni <= '0';
            else
                case instr_decoder is
                    when exp_slave_f8b_data | exp_slave_r8b_data =>
                        p_full_ni <= '1';
                    when others =>
                        p_full_ni <= '0';
                end case;
            end if;
        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                p_start <= '0';
            elsif instr_decoder = exp_slave_f8b_wACK or instr_decoder = exp_slave_f8b_data then
                p_start <= '1';
            else
                p_start <= '0';
            end if;
        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                p_stop <= '0';
            elsif instr_decoder = exp_slave_f8b_wACK or instr_decoder = exp_slave_r8b_wACK then
                if rem_data_xfer > 0 then
                    p_stop <= '0';
                else
                    p_stop <= '1';
                end if;
            elsif instr_decoder = exp_slave_f8b_data or instr_decoder = exp_slave_r8b_data then
                if rem_data_xfer > 1 then
                    p_stop <= '0';
                else
                    p_stop <= '1';
                end if;
            else
                p_stop <= '0';
            end if;
        end if;
    end process;


    process(clk)
    begin
        if rising_edge(clk) then
            case instr_decoder is
                when exp_slave_f16b_data | exp_slave_r16b_data =>
                    data_buffer <= din;
                when exp_slave_f8b_data  | exp_slave_r8b_data  =>
                    data_buffer <= din;
                when others                                    =>
                    null;
            end case;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                err_address <= '0';
            elsif instr_decoder = exp_cmd then
                err_address <= '0';  
            elsif curr_instruction = opcode_PCKT_EXC and instr_decoder = exp_slave_r8b_wACK then
                if timeout_cnt = TIMEOUT-1 then
                    err_address <= '1';                
                end if; 
            elsif err_addr = '1' then
                err_address <= '1';
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                err_fifo <= '0';
            elsif err_mstmx = '1' then
                err_fifo <= '1';
            elsif instr_decoder = wait_master_1st_ACK_rd or instr_decoder = wait_master_end_ACK_rd then
                if TXeni = '1' and TXrdy = '1' then
                    err_fifo <= '0';
                end if;                
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                err_nullsize <= '0';
            elsif instr_decoder = exp_cmd then
                err_nullsize <= '0';
            elsif instr_decoder = exp_len_LSB and (rem_data_xfer mod 256)= 0 and RXdat = x"00" and RXen = '1' and RXrdyi = '1' then
                err_nullsize <= '1';
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                err_timeout <= '0';
            elsif instr_decoder = exp_cmd then
                err_timeout <= '0';                
            elsif timeout_cnt = TIMEOUT-1 then
                if (curr_instruction /= opcode_PCKT_EXC or instr_decoder /= exp_slave_r8b_wACK) and err_address = '0' then
                    err_timeout <= '1';
                end if;
            end if;
        end if;
    end process;
    
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                timeout_cnt <= 0;
            else
                case instr_decoder is
                    when exp_slave_f16b_wACK | exp_slave_f16b_data | exp_slave_f8b_wACK | exp_slave_f8b_data |
                         exp_slave_r16b_wACK | exp_slave_r16b_data | exp_slave_r8b_data | exp_slave_r8b_wACK =>
                        if timeout_cnt < TIMEOUT-1 then
                            timeout_cnt <= timeout_cnt + 1;
                        end if;
                    when others =>
                        timeout_cnt <= 0;                        
                end case;
            end if;
        end if;
    end process;


end Behavioral;

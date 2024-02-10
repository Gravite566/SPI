-- This is a simulation model for the SPI_slave module
--
--
--
--


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity SPI_slave_SimModel is
    Generic ( SPI_MODE       : integer range 0 to  3 := 0;                      -- default SPI mode
              MSB_FIRST      : std_logic := '1';                                -- '1' : MSB first, '0' LSB first
	          BITS_PER_WORD  : integer range 8 to 32 := 8;                      -- how much bits contains a data word ?
              DEFAULT_VALUE  : std_logic_vector(31 downto 0) := x"00000000";    -- default value sent to master (when no data provided), lower bits when BITS_PER_WORD < 32
              DROP_NEW_DAT   : std_logic);                                      -- '1' : drops new data if no read on data_from_master and new data arrives, '0' : drops old data

    Port (  clk                 : in  std_logic;                                       -- system clock
            reset               : in  std_logic;                                       -- system reset (active high)

            SPI_SS              : in  std_logic;                                       -- SPI Slave Select from master
            SPI_SCK             : in  std_logic;                                       -- SPI clock from master
            SPI_MOSI            : in  std_logic;                                       -- SPI MOSI from master
            SPI_MISO            : out std_logic;                                       -- SPI MISO to master

            data_from_master    : out std_logic_vector(BITS_PER_WORD - 1 downto 0);    -- data sent by master
            data_from_master_en : out std_logic;                                       -- set when data_from_master is valid
            data_from_master_rd : in  std_logic;                                       -- read strobe from target module to clear data_from_master_en

            data_to_master      : in  std_logic_vector(BITS_PER_WORD - 1 downto 0);    -- next data to send to master
            data_to_master_en   : in  std_logic;                                       -- to inform that data_to_master is valid
            data_to_master_rd   : out std_logic;                                       -- read strobe to valid read action on data_to_master

            err_dropped_data_in : out std_logic;                                       -- set during 1 system clock period when a data word from master has been dropped (no read on data_from_master)
            err_sent_default    : out std_logic);                                      -- set during 1 system clock period when default data provided to master (no write on data_to_master)

end SPI_slave_SimModel;

architecture Behavioral of SPI_slave_SimModel is

    --signal bit_counter_in  : integer range 0 to BITS_PER_WORD - 1;              -- to count SPI_SCK periods on incoming word
    signal new_data        : std_logic_vector( BITS_PER_WORD - 1 downto 0);     -- to store incoming data word

    signal tx_data         : std_logic_vector( BITS_PER_WORD - 1 downto 0);     -- to store data word being sent
    signal next_data       : std_logic_vector( BITS_PER_WORD - 1 downto 0);     -- to store data word waiting for send
    signal next_data_valid : std_logic;                                         -- ='1' when next_data is valid
    signal next_to_tx_load : std_logic;                                         -- = '1' when tx_data needs to be loaded with next_data
    signal tx_data_loaded  : std_logic;                                         -- = '1' when next_data has been loaded in tx_data
    signal updt_dat2mstr   : std_logic := '0';                                  -- = '1' when data_to_master should be updated

    signal local_data_from_master_en : std_logic;
    signal local_data_to_master_rd   : std_logic;




begin



    -- manage the emission/reception of data
    process
        variable bitnum   : integer;
    begin
        if reset = '1' or SPI_SS = '1' then
            -- here, the module is not supposed to receive anything...
            -- if reset is cleared during a SPI transfer, this is not our problem
            SPI_MISO        <= 'Z';
            next_to_tx_load <= '0';
            wait until reset = '0' and SPI_SS = '0';
        end if;



        for i in 1 to BITS_PER_WORD loop
            if MSB_FIRST = '1' then
                bitnum := BITS_PER_WORD - i;
            else
                bitnum := i - 1;
            end if;

            if reset = '0' and SPI_SS = '0' then
                case SPI_MODE is
                    when      0 =>
                        SPI_MISO <= tx_data(bitnum);
                        if i = BITS_PER_WORD then next_to_tx_load <= '1', '0' after 1 ns; end if;
                        wait until rising_edge(SPI_SCK)  or reset = '1' or SPI_SS = '1';
                        if reset = '0' and SPI_SS = '0' then
                            new_data(bitnum) <= SPI_MOSI;
                            if i = BITS_PER_WORD then updt_dat2mstr   <= '1', '0' after 1 ns; end if;
                            wait until falling_edge(SPI_SCK) or reset = '1' or SPI_SS = '1';
                        end if;
                    when      1 =>
                        wait until rising_edge(SPI_SCK)  or reset = '1' or SPI_SS = '1';
                        if reset = '0' and SPI_SS = '0' then
                            SPI_MISO <= tx_data(bitnum);
                            if i = BITS_PER_WORD then next_to_tx_load <= '1', '0' after 1 ns; end if;
                            wait until falling_edge(SPI_SCK) or reset = '1' or SPI_SS = '1';
                        end if;
                        if reset = '0' and SPI_SS = '0' then
                            new_data(bitnum) <= SPI_MOSI;
                            if i = BITS_PER_WORD then updt_dat2mstr   <= '1', '0' after 1 ns; end if;
                        end if;
                    when      2 =>
                        SPI_MISO <= tx_data(bitnum);
                        if i = BITS_PER_WORD then next_to_tx_load <= '1', '0' after 1 ns; end if;
                        wait until falling_edge(SPI_SCK) or reset = '1' or SPI_SS = '1';
                        if reset = '0' and SPI_SS = '0' then
                            new_data(bitnum) <= SPI_MOSI;
                            if i = BITS_PER_WORD then updt_dat2mstr   <= '1', '0' after 1 ns; end if;
                            wait until rising_edge(SPI_SCK)  or reset = '1' or SPI_SS = '1';
                        end if;
                    when      3 =>
                        wait until falling_edge(SPI_SCK) or reset = '1' or SPI_SS = '1';
                        if reset = '0' and SPI_SS = '0' then
                            SPI_MISO <= tx_data(bitnum);
                            if i = BITS_PER_WORD then next_to_tx_load <= '1', '0' after 1 ns; end if;
                            wait until rising_edge(SPI_SCK)  or reset = '1' or SPI_SS = '1';
                        end if;
                        if reset = '0' and SPI_SS = '0' then
                            new_data(bitnum) <= SPI_MOSI;
                            if i = BITS_PER_WORD then updt_dat2mstr   <= '1', '0' after 1 ns; end if;
                        end if;
                end case;
            end if;
        end loop;
    end process;


--   #####                                                  #
--   #                                                      #
--   #      # ##    ###   ## #        ## #    ###    ####  ####    ###   # ##
--   ####   ##  #  #   #  # # #       # # #      #  #       #     #   #  ##  #
--   #      #      #   #  # # #       # # #   ####   ###    #     #####  #
--   #      #      #   #  # # #       # # #  #   #      #   #  #  #      #
--   #      #       ###   #   #       #   #   ####  ####     ##    ###   #
--



    data_from_master_en <= local_data_from_master_en;


    -- this process updates data_from_master
    process
    begin
        if reset = '1' or SPI_SS = '1' then
            -- here, the module is not supposed to receive anything...
            -- if reset is cleared during a SPI transfer, this is not our problem
            wait until reset = '0' and SPI_SS = '0';
        end if;

        wait until rising_edge(updt_dat2mstr);
        wait for 1 ps;
        wait until rising_edge(clk);

        if local_data_from_master_en = '0' or data_from_master_rd = '1' or DROP_NEW_DAT = '0' then
            -- only update data if
            --           previous data has been read (local_data_from_master_en = '0')
            --        or previous data is being read (data_from_master_rd = '1')
            --        or previous data should be dropped in case of conflict (DROP_NEW_DAT = '0')
            data_from_master <= new_data;
        end if;

    end process;

    -- let's hande local_data_from_master_en
    process
    begin
        if reset = '1' then
            -- initialize the value, there is no test on SPI_SS because if local_data_from_master_en, the transfer is actually
            -- over, and it may be a normal behavior to keep local_data_from_master_en set
            local_data_from_master_en <= '0';
            wait until reset = '0';
        end if;

        wait until rising_edge(updt_dat2mstr) or (rising_edge(clk) and data_from_master_rd = '1');

        if rising_edge(updt_dat2mstr) then
            -- here the process has been raised because of the end of a word...
            if reset = '0' and SPI_SS = '0' then
                -- just make sure that the end of the word is not just an interruption of the transfer
                wait for 1 ps;
                wait until rising_edge(clk);
                local_data_from_master_en <= '1';
            end if;
        elsif rising_edge(clk) and data_from_master_rd = '1' then
            -- data has just been read, there is no new data because of the elsif statement, so local_data_from_master_en can
            -- be cleanly cleared
            local_data_from_master_en <= '0';
        end if;

    end process;

    -- how about the error output ?
    process
    begin
        if reset = '1' then
            -- classic initialization
            err_dropped_data_in <= '0';
            wait until reset = '0';
        end if;

        wait until rising_edge(updt_dat2mstr) or reset = '1';

        if reset = '0' and SPI_SS = '0' then
            -- still need to check if this is not the reseult of a reset ...
            wait until rising_edge(clk);
            if local_data_from_master_en = '1' and data_from_master_rd = '0' then
                err_dropped_data_in <= '1';
                wait until rising_edge(clk);
                err_dropped_data_in <= '0';
            end if;
        end if;

    end process;


--   #####                                    #
--     #                                      #
--     #     ###        ## #    ###    ####  ####    ###   # ##
--     #    #   #       # # #      #  #       #     #   #  ##  #
--     #    #   #       # # #   ####   ###    #     #####  #
--     #    #   #       # # #  #   #      #   #  #  #      #
--     #     ###        #   #   ####  ####     ##    ###   #
--


    data_to_master_rd <= local_data_to_master_rd;


    -- manage the value of tx_data
    process
    begin
        if reset = '1' then
            -- initial step, but no action when SS is high, this is normal behavior
            tx_data          <= DEFAULT_VALUE(BITS_PER_WORD - 1 downto 0);
            tx_data_loaded   <= '0';
            err_sent_default <= '0';
            wait until reset = '0';
        end if;

        wait until rising_edge(next_to_tx_load);

        -- in this part, we synchronize on clk because signals have consequences on user
        -- area which is synchronized on clk...
        if next_data_valid = '1' then
            -- there is data from user, take it and mark it as used
            tx_data <= next_data;
            tx_data_loaded <= '1';
            wait until rising_edge(clk);
            tx_data_loaded <= '0';
        else
            -- no data loaded, take the default one and raise the error
            tx_data <= DEFAULT_VALUE(BITS_PER_WORD - 1 downto 0);
            err_sent_default <= '1';
            wait until rising_edge(clk);
            err_sent_default <= '0';
        end if;
    end process;


    -- manage the value of next_data
    process
    begin
        if reset = '1' then
            -- initial step, but no action when SS is high, this is normal behavior
            next_data       <= DEFAULT_VALUE(BITS_PER_WORD - 1 downto 0);
            next_data_valid <= '0';
            wait until reset = '0';
        end if;

        wait until rising_edge(clk) and (tx_data_loaded = '1' or (data_to_master_en = '1' and local_data_to_master_rd = '1') or reset = '1');
        if tx_data_loaded = '1' then
            -- previous data has been used, load defaul value, just in case
            next_data       <= DEFAULT_VALUE(BITS_PER_WORD - 1 downto 0);
            next_data_valid <= '0';
        elsif data_to_master_en = '1' and local_data_to_master_rd = '1' then
            -- new data loaded by user, mark it as ready
            next_data       <= data_to_master;
            next_data_valid <= '1';
        end if;
    end process;

    local_data_to_master_rd <= not next_data_valid;


end Behavioral;

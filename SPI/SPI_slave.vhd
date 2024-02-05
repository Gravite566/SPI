-- This is a synthetizable model for the SPI_slave module
--


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity SPI_slave is
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

end SPI_slave;

architecture Behavioral of SPI_slave is




begin


end Behavioral;

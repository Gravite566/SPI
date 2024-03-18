----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.03.2024 14:25:34
-- Design Name: 
-- Module Name: top_level_SPI - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top_level_SPI is
    Generic ( SPI_MODE       : integer range 0 to  3 := 0;                             -- default SPI mode
              MSB_FIRST      : std_logic := '1';                                       -- '1' : MSB first, '0' LSB first
	          BITS_PER_WORD  : integer range 8 to 32 := 8;                                 -- how much bits contains a data word ?
              DEFAULT_VALUE  : std_logic_vector(31 downto 0) := x"00000000";           -- default value sent to master (when no data provided), lower bits when BITS_PER_WORD < 32
              DROP_NEW_DAT   : std_logic := '1');
                    
    Port ( SW : in STD_LOGIC_VECTOR (BITS_PER_WORD - 1 downto 0);
           CLK100MHZ : in STD_LOGIC;
           JD   : inout STD_LOGIC_VECTOR(12 downto 1);
           BTNR : in STD_LOGIC;
           LED : out STD_LOGIC_VECTOR (BITS_PER_WORD - 1 downto 0);
           LED16_R : out STD_LOGIC;
           LED16_G : out STD_LOGIC;
           LED17_R : out STD_LOGIC;
           LED17_G : out STD_LOGIC);
end top_level_SPI;

architecture Behavioral of top_level_SPI is

component SPI_slaveV3 is
    Port (  clk                 : in  std_logic;                                       -- system clock
            reset               : in  std_logic;                                       -- system reset (active high)

            SPI_SS              : in  std_logic;                                       -- SPI Slave Select from master
            SPI_SCK             : in  std_logic;                                       -- SPI clock from master
            SPI_MOSI            : in  std_logic;                                       -- SPI MOSI from master
            SPI_MISO            : out std_logic;                                       -- SPI MISO to master

            data_from_master    : out std_logic_vector(BITS_PER_WORD - 1 downto 0);    -- data sent by master
            data_from_master_en : out std_logic;                                      -- set when data_from_master is valid
            data_from_master_rd : in  std_logic;                                       -- read strobe from target module to clear data_from_master_en

            data_to_master      : in  std_logic_vector(BITS_PER_WORD - 1 downto 0);    -- next data to send to master
            data_to_master_en   : in  std_logic;                                       -- to inform that data_to_master is valid
            data_to_master_rd   : out std_logic;                                       -- read strobe to valid read action on data_to_master

            err_dropped_data_in : out std_logic;                                       -- set during 1 system clock period when a data word from master has been dropped (no read on data_from_master)
            err_sent_default    : out std_logic);                                      -- set during 1 system clock period when default data provided to master (no write on data_to_master)

end component;

signal s_data_from_rd : STD_LOGIC := '1';
signal s_data_to_en : STD_LOGIC := '1';

begin

Sub_mod : SPI_slaveV3
    Port map (clk => CLK100MHZ,
            reset => BTNR,
            SPI_SS => JD(1),
            SPI_SCK => JD(10),
            SPI_MOSI => JD(9),
            SPI_MISO => JD(7),

            data_from_master => LED,
            data_from_master_en => LED17_G,
            data_from_master_rd => s_data_from_rd,

            data_to_master => SW,
            data_to_master_en => s_data_to_en,
            data_to_master_rd => LED16_G,
            err_dropped_data_in => LED17_R,
            err_sent_default => LED16_R);

end Behavioral;

----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/19/2024 03:14:12 PM
-- Design Name: 
-- Module Name: tb_SPI_SUB - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_SPI_SUB is
    Generic ( SPI_MODE       : integer range 0 to  3 := 0;                             -- default SPI mode
              MSB_FIRST      : std_logic := '1';                                       -- '1' : MSB first, '0' LSB first
	      BITS_PER_WORD  : integer range 8 to 32 := 8;                                 -- how much bits contains a data word ?
              DEFAULT_VALUE  : std_logic_vector(31 downto 0) := x"00000000";           -- default value sent to master (when no data provided), lower bits when BITS_PER_WORD < 32
              DROP_NEW_DAT   : std_logic := '1');                                      -- '1' : drops new data if no read on data_from_master and new data arrives, '0' : drops old data
end tb_SPI_SUB;

architecture Behavioral of tb_SPI_SUB is

component SPI_slaveV2 is

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
end component;


signal s_clk        : std_logic := '0';
signal s_rst        : std_logic := '1';
signal s_spi_ss     : std_logic := '1';
signal s_spi_sck    : std_logic := '0';
signal s_spi_MOSI   : std_logic;
signal s_spi_MISO   : std_logic := '0';
signal s_data_from  : std_logic_vector(BITS_PER_WORD - 1 downto 0);
signal s_data_to    : std_logic_vector(BITS_PER_WORD - 1 downto 0) := "01011001";
signal s_data_from_en   : std_logic;
signal s_data_to_en     : std_logic := '1';
signal s_data_from_rd   : std_logic := '1';
signal s_data_to_rd     : std_logic;
signal s_err_dropdata   : std_logic;
signal s_err_sentdef    : std_logic;
            
begin

s_rst <= '0' after 50 ns;
s_clk <= not(s_clk) after 1 ns;
s_spi_ss <= '0' after 70 ns;
s_spi_sck <= not(s_spi_sck) after 10 ns;
s_spi_MOSI <= '1' after 70 ns, '0' after 90 ns, '1' after 110 ns, '0' after 130 ns, '0' after 150 ns, '1' after 170 ns, '1' after 190 ns, '1' after 210 ns,
              '0' after 230 ns, '0' after 250 ns, '0' after 270 ns, '1' after 290 ns, '1' after 310 ns, '0' after 330 ns, '1' after 350 ns, '0' after 370 ns;
s_data_to <= "01100111" after 230ns;


tb_spi_sub : SPI_slaveV2
    Port map (clk => s_clk,
            reset => s_rst,
            SPI_SS => s_spi_ss,
            SPI_SCK => s_spi_sck,
            SPI_MOSI => s_spi_mosi,
            SPI_MISO => s_spi_miso,

            data_from_master => s_data_from,
            data_from_master_en => s_data_from_en,
            data_from_master_rd => s_data_from_rd,

            data_to_master => s_data_to,
            data_to_master_en => s_data_to_en,
            data_to_master_rd => s_data_to_rd,
            err_dropped_data_in => s_err_dropdata,
            err_sent_default => s_err_sentdef);


end Behavioral;

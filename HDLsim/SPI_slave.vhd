-- This is a dummy entity for the SPI_slave module, just to make simulation tool compile
--


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity SPI_slave is
    Generic ( SPI_MODE       : integer range 0 to  3 := 0;                             -- default SPI mode
              MSB_FIRST      : std_logic := '1';                                       -- '1' : MSB first, '0' LSB first
	      BITS_PER_WORD  : integer range 8 to 32 := 8;                                 -- how much bits contains a data word ?
              DEFAULT_VALUE  : std_logic_vector(31 downto 0) := x"00000000";           -- default value sent to master (when no data provided), lower bits when BITS_PER_WORD < 32
              DROP_NEW_DAT   : std_logic := '1');                                      -- '1' : drops new data if no read on data_from_master and new data arrives, '0' : drops old data

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

signal bit_count    : unsigned(5 downto 0):= "000000";
signal local_count  : unsigned(5 downto 0):= "000000";
signal bits_send    : unsigned(5 downto 0):= "000000";
signal last_sck     : std_logic := '0';
signal ech_mosi     : std_logic;

signal word_to_send  : std_logic_vector(BITS_PER_WORD - 1 downto 0); --Mot binaire a transmettre en cours de deconstruction
signal word_received : std_logic_vector(BITS_PER_WORD - 1 downto 0); --Mot binaire a transmettre en cours de construction

begin

-- Sample de MOSI à chaque nouveau passage à 1 de SCLK
sampler : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            ech_mosi <= '0';
        elsif (data_from_master_rd = '0') then -- gestion du DROP_NEW_DATA ici
            ech_mosi <= '0';
        else
            ech_mosi <= SPI_MOSI;
        end if;
    end if;
end process;


-- Construction du mot binaire a envoyer
shift_register : process (clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            word_received <= (others => '0');
	        local_count <= "000000";
        elsif (bit_count = 0) then
            local_count <= "000000";
        elsif (bit_count = 1) then
            word_received(0) <= ech_mosi;
            local_count <= "000001";
        elsif (local_count < bit_count) then
            word_received <= word_received(BITS_PER_WORD - 2 downto 0) & '0';
            word_received(0) <= ech_mosi;
            local_count <= local_count + 1;
	    elsif (local_count = BITS_PER_WORD) then
	        data_from_master <= word_received; --manque gestion des ready et réinitialisation quand envoi effectué
        end if;
    end if;
end process;

            
-- Compteur de bits deja recus
counter : process (clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            bit_count <= "000000";
        elsif (SPI_SCK = '1') then
            if (last_sck = '0') then
                last_sck <= '1';
                if (bit_count < BITS_PER_WORD) then
                    bit_count <= bit_count + 1;
                else
                    bit_count <= "000000";
                end if;
            else
                last_sck <= '1';
            end if;
        else
            last_sck <= '0';
        end if;
    end if;
end process;

-- Reconstruction du signal binaire sur MISO
MISO_builder : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then
            SPI_MISO <= '0';
            bits_send <= "000000";
            data_to_master_rd <= '0';
        elsif (data_to_master_en = '0') then
            SPI_MISO <= '0';
            bits_send <= "000000";
            data_to_master_rd <= '0';
        elsif (data_to_master_en = '1') then
            data_to_master_rd <= '1';
            if (bit_count = 0) then
                word_to_send <= data_to_master;
            elsif (bits_send < bit_count) then
                SPI_MISO <= word_to_send(0);
                word_to_send <= word_to_send(BITS_PER_WORD - 2 downto 0) & '0';
                bits_send <= bits_send + 1;
            elsif (bits_send = BITS_PER_WORD) then
                bits_send <= "000000";
            end if;
        end if;
    end if;
end process;        
            
end Behavioral;	
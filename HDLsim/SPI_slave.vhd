-- This is a dummy entity for the SPI_slave module, just to make simulation tool compile
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

signal bit_count    : unsigned(5 downto 0):= "000000";
signal local_count  : unsigned(5 downto 0):= "000000"; --pas sur de cette méthode pour construire le mot 
signal last_sck     : std_logic := '0';
signal ech_mosi     : std_logic;
signal word_to_send : std_logic_vector(BITS_PER_WORD - 1 downto 0);

begin

-- Sample de MOSI à chaque nouveau passage à 1 de SCLK
sampler : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            ech_mosi <= '0';
        elsif (SPI_SCK = '1') then
            ech_mosi <= SPI_MOSI;
        end if;
    end if;
end process;

-- Compteur de bits deja recus
counter : process (clk)
begin
    if (rising_edge(clk)) then
        if reset = '1' then 
            bit_count <= "000000";
        elsif SPI_SCK = '1' then
            if last_sck = '0' then
                last_sck <= '1';
                if bit_count < BITS_PER_WORD then
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

-- Construction du mot binaire a envoyer (process combinatoire de bit_count ??) vraiment pas propre, a revoir
shift_register : process (clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            data_from_master <= (others => '0');
        elsif (bit_count = 0) then
            word_to_send(0) <= ech_mosi;
            local_count <= "000000";
        elsif (bit_count /= local_count) then
            word_to_send <= word_to_send -- décalage à gauche de 1;
            
            
            


end Behavioral;-- This is a dummy entity for the SPI_slave module, just to make simulation tool compile
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

signal bit_count    : unsigned(5 downto 0):= "000000";
signal local_count  : unsigned(5 downto 0):= "000000"; --pas sur de cette méthode pour construire le mot 
signal last_sck     : std_logic := '0';
signal ech_mosi     : std_logic;
signal word_to_send : std_logic_vector(BITS_PER_WORD - 1 downto 0);

begin

-- Sample de MOSI à chaque nouveau passage à 1 de SCLK
sampler : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            ech_mosi <= '0';
        elsif (SPI_SCK = '1') then
            ech_mosi <= SPI_MOSI;
        end if;
    end if;
end process;

-- Compteur de bits deja recus
counter : process (clk)
begin
    if (rising_edge(clk)) then
        if reset = '1' then 
            bit_count <= "000000";
        elsif SPI_SCK = '1' then
            if last_sck = '0' then
                last_sck <= '1';
                if bit_count < BITS_PER_WORD then
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

-- Construction du mot binaire a envoyer (process combinatoire de bit_count ??) vraiment pas propre, a revoir
shift_register : process (clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            data_from_master <= (others => '0');
        elsif (bit_count = 0) then
            word_to_send(0) <= ech_mosi;
            local_count <= "000000";
        elsif (bit_count /= local_count) then
            word_to_send <= word_to_send -- décalage à gauche de 1;
            
            
            


end Behavioral;
-- This is a dummy entity for the SPI_slave module, just to make simulation tool compile
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

signal bit_count    : unsigned(5 downto 0):= "000000";
signal local_count  : unsigned(5 downto 0):= "000000"; --pas sur de cette méthode pour construire le mot 
signal last_sck     : std_logic := '0';
signal ech_mosi     : std_logic;
signal word_to_send : std_logic_vector(BITS_PER_WORD - 1 downto 0);

begin

-- Sample de MOSI à chaque nouveau passage à 1 de SCLK
sampler : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            ech_mosi <= '0';
        elsif (SPI_SCK = '1') then
            ech_mosi <= SPI_MOSI;
        end if;
    end if;
end process;

-- Compteur de bits deja recus
counter : process (clk)
begin
    if (rising_edge(clk)) then
        if reset = '1' then 
            bit_count <= "000000";
        elsif SPI_SCK = '1' then
            if last_sck = '0' then
                last_sck <= '1';
                if bit_count < BITS_PER_WORD then
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

-- Construction du mot binaire a envoyer (process combinatoire de bit_count ??) vraiment pas propre, a revoir
shift_register : process (clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            data_from_master <= (others => '0');
        elsif (bit_count = 0) then
            word_to_send(0) <= ech_mosi;
            local_count <= "000000";
        elsif (bit_count /= local_count) then
            word_to_send <= word_to_send -- décalage à gauche de 1;
            
            
            


end Behavioral;
-- This is a dummy entity for the SPI_slave module, just to make simulation tool compile
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

signal bit_count    : unsigned(5 downto 0):= "000000";
signal local_count  : unsigned(5 downto 0):= "000000"; --pas sur de cette méthode pour construire le mot 
signal last_sck     : std_logic := '0';
signal ech_mosi     : std_logic;
signal word_to_send : std_logic_vector(BITS_PER_WORD - 1 downto 0);

begin

-- Sample de MOSI à chaque nouveau passage à 1 de SCLK
sampler : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            ech_mosi <= '0';
        elsif (SPI_SCK = '1') then
            ech_mosi <= SPI_MOSI;
        end if;
    end if;
end process;

-- Compteur de bits deja recus
counter : process (clk)
begin
    if (rising_edge(clk)) then
        if reset = '1' then 
            bit_count <= "000000";
        elsif SPI_SCK = '1' then
            if last_sck = '0' then
                last_sck <= '1';
                if bit_count < BITS_PER_WORD then
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

-- Construction du mot binaire a envoyer (process combinatoire de bit_count ??) vraiment pas propre, a revoir
shift_register : process (clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            data_from_master <= (others => '0');
        elsif (bit_count = 0) then
            word_to_send(0) <= ech_mosi;
            local_count <= "000000";
        elsif (bit_count /= local_count) then
            word_to_send <= word_to_send -- décalage à gauche de 1;
            
            
            


end Behavioral;
-- This is a dummy entity for the SPI_slave module, just to make simulation tool compile
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

signal bit_count    : unsigned(5 downto 0):= "000000";
signal local_count  : unsigned(5 downto 0):= "000000"; --pas sur de cette méthode pour construire le mot 
signal last_sck     : std_logic := '0';
signal ech_mosi     : std_logic;
signal word_to_send : std_logic_vector(BITS_PER_WORD - 1 downto 0);

begin

-- Sample de MOSI à chaque nouveau passage à 1 de SCLK
sampler : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            ech_mosi <= '0';
        elsif (SPI_SCK = '1') then
            ech_mosi <= SPI_MOSI;
        end if;
    end if;
end process;

-- Compteur de bits deja recus
counter : process (clk)
begin
    if (rising_edge(clk)) then
        if reset = '1' then 
            bit_count <= "000000";
        elsif SPI_SCK = '1' then
            if last_sck = '0' then
                last_sck <= '1';
                if bit_count < BITS_PER_WORD then
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

-- Construction du mot binaire a envoyer (process combinatoire de bit_count ??) vraiment pas propre, a revoir
shift_register : process (clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            data_from_master <= (others => '0');
        elsif (bit_count = 0) then
            word_to_send(0) <= ech_mosi;
            local_count <= "000000";
        elsif (bit_count /= local_count) then
            word_to_send <= word_to_send -- décalage à gauche de 1;
            
            
            


end Behavioral;
-- This is a dummy entity for the SPI_slave module, just to make simulation tool compile
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

signal bit_count    : unsigned(5 downto 0):= "000000";
signal local_count  : unsigned(5 downto 0):= "000000"; --pas sur de cette méthode pour construire le mot 
signal last_sck     : std_logic := '0';
signal ech_mosi     : std_logic;
signal word_to_send : std_logic_vector(BITS_PER_WORD - 1 downto 0);

begin

-- Sample de MOSI à chaque nouveau passage à 1 de SCLK
sampler : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            ech_mosi <= '0';
        elsif (SPI_SCK = '1') then
            ech_mosi <= SPI_MOSI;
        end if;
    end if;
end process;

-- Compteur de bits deja recus
counter : process (clk)
begin
    if (rising_edge(clk)) then
        if reset = '1' then 
            bit_count <= "000000";
        elsif SPI_SCK = '1' then
            if last_sck = '0' then
                last_sck <= '1';
                if bit_count < BITS_PER_WORD then
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

-- Construction du mot binaire a envoyer (process combinatoire de bit_count ??) vraiment pas propre, a revoir
shift_register : process (clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            data_from_master <= (others => '0');
        elsif (bit_count = 0) then
            word_to_send(0) <= ech_mosi;
            local_count <= "000000";
        elsif (bit_count /= local_count) then
            word_to_send <= word_to_send -- décalage à gauche de 1;
            
            
            


end Behavioral;
-- This is a dummy entity for the SPI_slave module, just to make simulation tool compile
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

signal bit_count    : unsigned(5 downto 0):= "000000";
signal local_count  : unsigned(5 downto 0):= "000000"; --pas sur de cette méthode pour construire le mot 
signal last_sck     : std_logic := '0';
signal ech_mosi     : std_logic;
signal word_to_send : std_logic_vector(BITS_PER_WORD - 1 downto 0);

begin

-- Sample de MOSI à chaque nouveau passage à 1 de SCLK
sampler : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            ech_mosi <= '0';
        elsif (SPI_SCK = '1') then
            ech_mosi <= SPI_MOSI;
        end if;
    end if;
end process;

-- Compteur de bits deja recus
counter : process (clk)
begin
    if (rising_edge(clk)) then
        if reset = '1' then 
            bit_count <= "000000";
        elsif SPI_SCK = '1' then
            if last_sck = '0' then
                last_sck <= '1';
                if bit_count < BITS_PER_WORD then
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

-- Construction du mot binaire a envoyer (process combinatoire de bit_count ??) vraiment pas propre, a revoir
shift_register : process (clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            data_from_master <= (others => '0');
        elsif (bit_count = 0) then
            word_to_send(0) <= ech_mosi;
            local_count <= "000000";
        elsif (bit_count /= local_count) then
            word_to_send <= word_to_send -- décalage à gauche de 1;
            
            
            


end Behavioral;



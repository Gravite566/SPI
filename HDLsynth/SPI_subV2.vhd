-- This is a dummy entity for the SPI_slave module, just to make simulation tool compile
--


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity SPI_slaveV2 is
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

end SPI_slaveV2;

architecture Behavioral of SPI_slaveV2 is

signal bit_count    : unsigned(5 downto 0):= "000000";
signal local_count  : unsigned(5 downto 0):= "000000";
signal last_sck     : std_logic := '0';
signal ech_mosi     : std_logic;

signal word_in_mem  : std_logic_vector(BITS_PER_WORD - 1 downto 0); --Mot binaire en mémoire (mot a envoyer qui laisse place au mot recu)
--signal word_received : std_logic_vector(BITS_PER_WORD - 1 downto 0); --Mot binaire a transmettre en cours de construction

begin

-- Compteur de bits deja recus
counter : process (clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            bit_count <= "000000";
            word_in_mem <= (others => '0');
        elsif (SPI_SS = '1') then
            bit_count <= "000000";
            word_in_mem <= (others => '0');
        elsif (SPI_SCK = '1') then
            if (last_sck = '0') then --Front montant de SCK, gestion de l'envoi
                last_sck <= '1';
                if (bit_count = 0) then --Aucune donnée encore envoyée, initialisation
                    if (data_to_master_en = '1') then --si data a envoyer, on la prepare en la recopiant dans le registre, puis on indique qu'elle est prete
                        word_in_mem <= data_to_master;  
                        data_to_master_rd <= '1';
                        SPI_MISO <= word_in_mem(BITS_PER_WORD - 1);
                    else  --sinon envoi de la valeur par defaut et signal d'erreur
                        word_in_mem <= DEFAULT_VALUE(BITS_PER_WORD - 1 downto 0);
                        err_sent_default <= '1';       
                    end if;
                    bit_count <= bit_count + 1;         
                elsif (bit_count < BITS_PER_WORD - 1) then -- Mot en cours d'envoi
                    SPI_MISO <= word_in_mem(BITS_PER_WORD - 1);
                    bit_count <= bit_count + 1;
                else --Mot envoyé
                    bit_count <= "000000";
                end if;
            else
                last_sck <= '1';
            end if;
        elsif last_sck = '1' then --Front descendant de SCLK, gestion de la réception
            last_sck <= '0';            
            if (bit_count < BITS_PER_WORD - 1) then --Mot en cours de réception, bit précédent déjà envoyé
                word_in_mem <= word_in_mem(BITS_PER_WORD - 2 downto 0) & '0';
                word_in_mem(0) <= SPI_MOSI;
            elsif (bit_count = BITS_PER_WORD - 1) then --Dernier bit à recevoir, mot totalement envoyé
                word_in_mem <= word_in_mem(BITS_PER_WORD - 2 downto 0) & '0';
                word_in_mem(0) <= SPI_MOSI;
                if (data_from_master_rd = '1') then
                    data_from_master_en <= '1';
                    data_from_master <= word_in_mem;
                else
                    err_dropped_data_in <= '1';
                end if;
            end if;
        end if;
    end if;
end process;


end Behavioral;
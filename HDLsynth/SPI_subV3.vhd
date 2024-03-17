----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.03.2024 15:33:03
-- Design Name: 
-- Module Name: SPI_slaveV3 - Behavioral
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


entity SPI_slaveV3 is
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

end SPI_slaveV3;

architecture Behavioral of SPI_slaveV3 is

signal bit_count    : unsigned(5 downto 0):= "000000";
signal reg_count    : unsigned(5 downto 0):= "000000";

signal last_sck     : std_logic := '0';
signal front_montant    : std_logic := '0';
signal front_descendant : std_logic := '0';

signal word_end : std_logic := '0';
signal load_complete : std_logic := '0';

signal data_tx : std_logic := '0';
signal data_rx : std_logic := '0';


signal word_in_mem  : std_logic_vector(BITS_PER_WORD - 1 downto 0); --Mot binaire en mémoire (mot a envoyer qui laisse place au mot recu)
begin

-- Compteur de bits deja recus et detecteur de fronts
counter : process (clk)
begin
    if (rising_edge(clk)) then
        front_montant    <= '0';
        front_descendant <= '0';
        if (reset = '1') then 
            bit_count <= "000000";
        elsif (SPI_SS = '1') then
            bit_count <= "000000";
        elsif (SPI_SCK = '1') then
            if (last_sck = '0') then --Front montant de SCK, gestion de l'envoi
                front_montant <= '1';
                last_sck      <= '1';
                if (bit_count < BITS_PER_WORD) then
                    bit_count <= bit_count + 1;
                else
                    bit_count <= "000000";
                end if;
            else         
                last_sck <= '1';
            end if;
        elsif last_sck = '1' then --Front descendant de SCLK, gestion de la réception
            front_descendant <= '1';
            last_sck         <= '0';
        end if;
    end if;
end process;


tx_mod : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            SPI_MISO <= '0';
        elsif (SPI_SS = '1') then
            SPI_MISO <= '0';
        elsif (SPI_SCK = '1') then
            SPI_MISO <= data_tx;
        end if;
    end if;
end process;


rx_mod : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            data_rx <= '0';
        elsif (SPI_SS = '1') then
            data_rx <= '0';
        elsif (SPI_SCK = '1') then
            data_rx <= SPI_MOSI;
        end if;
    end if;
end process;


shift_register : process(clk)
begin
    if (rising_edge(clk)) then
        if (reset = '1') then 
            word_in_mem <= (others => '0');
            data_from_master_en <= '0';
            data_to_master_rd   <= '0';
            err_dropped_data_in <= '0';
            err_sent_default    <= '0';
            load_complete       <= '0';
        elsif (SPI_SS = '1') then
            word_in_mem <= (others => '0');
            data_from_master_en <= '0';
            data_to_master_rd   <= '0';
            err_dropped_data_in <= '0';
            err_sent_default    <= '0';
            load_complete       <= '0';
        elsif (bit_count = 0) then --Aucune donnée encore envoyée, initialisation
            if (load_complete = '0') then
                if (data_to_master_en = '1') then   --si data a envoyer, on la prepare en la recopiant dans le registre
                    data_to_master_rd <= '1';
                    word_in_mem <= data_to_master;
                    data_tx <= word_in_mem(BITS_PER_WORD - 1);
                    load_complete <= '1';
                elsif (data_to_master_en = '0') then --sinon envoi de la valeur par defaut et signal d'erreur
                    word_in_mem <= DEFAULT_VALUE(BITS_PER_WORD - 1 downto 0);
                    err_sent_default <= '1';
                    data_tx <= word_in_mem(BITS_PER_WORD - 1);
                    load_complete <= '1';
                end if;
            elsif (front_descendant = '1') then
                    word_in_mem <= word_in_mem(BITS_PER_WORD - 2 downto 0) & '0';
                    word_in_mem(0) <= data_rx;
            end if;
        elsif (bit_count < BITS_PER_WORD) then --Mot en cours de réception
            load_complete <= '0';
            if (front_montant = '1') then
                data_tx <= word_in_mem(BITS_PER_WORD - 1);
            elsif (front_descendant = '1') then
                word_in_mem <= word_in_mem(BITS_PER_WORD - 2 downto 0) & '0';
                word_in_mem(0) <= data_rx;
            end if;
        elsif (bit_count = BITS_PER_WORD) then -- Dernier bit a envoyer
            if (front_montant = '1') then
                data_tx <= word_in_mem(BITS_PER_WORD - 1);
            elsif (front_descendant = '1') then
                word_in_mem <= word_in_mem(BITS_PER_WORD - 2 downto 0) & '0';
                word_in_mem(0) <= data_rx;
                word_end <= '1';
            elsif (word_end = '1') then
                if (data_from_master_rd = '1') then
                    data_from_master_en <= '1';
                    data_from_master <= word_in_mem;
                else
                    err_dropped_data_in <= '1'; --gestion du drop_new_dat ici
                end if;
                word_end <= '0';
            end if;
        end if;               
    end if;               
end process;

end Behavioral;
--SUBMODULE SPI_slave_SimModel.vhd
--SUBMODULE SPI_slave.vhd
--SIMTIME   20000us
--GENERIC   SPI_MODE      = 0, 1, 2, 3
--GENERIC   BITS_PER_WORD = 32, 16, 11, 8
--GENERIC   DEFAULT_VALUE = 21845, 0, -1
--GENERIC   DROP_NEW_DAT  = 0, 1
--GENERIC   MSB_FIRST     = 1, 0

-- This testbench is not definitive and considers an abnormally early load of response data
-- resulting in a pipeline/delay in data flowing from slave to master

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity tb_SPI_slave is
    Generic ( MODEL          : integer range 0 to  1 := 1;
              SPI_MODE       : integer range 0 to  3 := 0;
              MSB_FIRST      : integer range 0 to  1 := 1;
	          BITS_PER_WORD  : integer range 8 to 32 := 8;
              DEFAULT_VALUE  : integer;
              DROP_NEW_DAT   : integer range 0 to  1 := 1);

end tb_SPI_slave;

architecture Behavioral of tb_SPI_slave is

    constant MSB_FIRST_GEN    : std_logic_vector( 0 downto 0) := std_logic_vector(to_unsigned(MSB_FIRST   , 1));
    constant DROP_NEW_DAT_GEN : std_logic_vector( 0 downto 0) := std_logic_vector(to_unsigned(DROP_NEW_DAT, 1));
    constant DEFAULT_GEN      : std_logic_vector(31 downto 0) := std_logic_vector(to_signed(DEFAULT_VALUE, 32));

    constant clk_period     : time := 10 ns; -- 100 MHz
    constant TARGET_SPI_PER : time :=  5 ns; -- 200 MHz


    --   #   #                ###
    --   #   #                 #
    --   #   #   ###   ##  #   #   ## #    ###    ###    ###
    --   #####  #   #    ##    #   # # #      #  #   #  #   #
    --   #   #  #####    #     #   # # #   ####  #  ##  #####
    --   #   #  #       ##     #   # # #  #   #   ## #  #
    --   #   #   ###   #  ##  ###  #   #   ####      #   ###
    --                                            ###
    -- HexImage makes it possible to render std_logic_vector values to text in Hex form
    -- quite useful for reports. '?' chars are displayed when a given nible contains
    -- non binary values
    function HexImage(L: std_logic_vector) return String is
        variable cpy     : std_logic_vector(L'left+3 downto L'right);
        variable res     : string(1 to (L'length+3)/4);
        variable nible   : std_logic_vector(3 downto 0);
        variable dstsize : integer;
    begin
        -- cpy is to make sure that there is no incomplete nible
        cpy                        := (others => '0');
        cpy(L'left downto L'right) := L;
        dstsize                    := (L'length+3)/4;

        for i in 0 to dstsize-1 loop
            nible := cpy(i*4+3 + L'right downto i*4 + L'right);
            case nible is
                when "0000" => res(dstsize-i) := '0';
                when "0001" => res(dstsize-i) := '1';
                when "0010" => res(dstsize-i) := '2';
                when "0011" => res(dstsize-i) := '3';
                when "0100" => res(dstsize-i) := '4';
                when "0101" => res(dstsize-i) := '5';
                when "0110" => res(dstsize-i) := '6';
                when "0111" => res(dstsize-i) := '7';
                when "1000" => res(dstsize-i) := '8';
                when "1001" => res(dstsize-i) := '9';
                when "1010" => res(dstsize-i) := 'A';
                when "1011" => res(dstsize-i) := 'B';
                when "1100" => res(dstsize-i) := 'C';
                when "1101" => res(dstsize-i) := 'D';
                when "1110" => res(dstsize-i) := 'E';
                when "1111" => res(dstsize-i) := 'F';
                when others => res(dstsize-i) := '?';
            end case;
        end loop;
        return (res);
    end function HexImage;


    --   ####    #          ###
    --   #   #               #
    --   #   #  ##   # ##    #   ## #    ###    ###    ###
    --   ####    #   ##  #   #   # # #      #  #   #  #   #
    --   #   #   #   #   #   #   # # #   ####  #  ##  #####
    --   #   #   #   #   #   #   # # #  #   #   ## #  #
    --   ####   ###  #   #  ###  #   #   ####      #   ###
    --                                          ###
    -- BinImage makes it possible to render std_logic_vector values to text in 'binary' form
    -- more verbose and less readable than HexImage, but more precise when std_logic values
    -- other than '0' or '1' are involved
    function BinImage(L: std_logic_vector) return String is
        variable res   : string(1 to L'length);
    begin
        for i in L'right to L'left loop
            res(L'length - i + L'right) := std_logic'image(l(i))(2);
        end loop;
        return (res);
    end function BinImage;


    --   #####                       ###
    --   #                            #
    --   #      # ##    ###    ####   #   ## #    ###    ###    ###
    --   ####   ##  #  #   #  #   #   #   # # #      #  #   #  #   #
    --   #      #      #####  #   #   #   # # #   ####  #  ##  #####
    --   #      #      #       ####   #   # # #  #   #   ## #  #
    --   #      #       ###       #  ###  #   #   ####      #   ###
    --                            #                      ###
    -- converts time type to string representation of the corresponding frequency
    function FreqImage(T: time) return String is
        variable frq   : integer;
        variable res   : string(1 to 10); -- chars 7 to 10 are for unit
        variable ints  : string(1 to  7); -- intermediate string conversion
    begin
        if    T > 1 sec then
            report "Cannont handle frequencies lower than 1Hz" severity error;
        elsif T > 1 ms then
            frq          := (1000 sec) / T;
            res(7 to 10) := "  Hz";
        elsif T > 1 us then
            frq          := (1 sec) / T;
            res(7 to 10) := " kHz";
        elsif T > 1 ns then
            frq          := (1 ms) / T;
            res(7 to 10) := " MHz";
        else
            frq          := (1 us) / T;
            res(7 to 10) := " GHz";
        end if;

        ints := integer'image(frq + 1000000);
        if    frq >= 100000 then
            res(1 to 3) := ints(2 to 4);
            res(4)      := '.';
            res(5 to 6) := ints(5 to 6);
        elsif frq >=  10000 then
            res(1 to 2) := ints(3 to 4);
            res(3)      := '.';
            res(4 to 6) := ints(5 to 7);
        elsif frq >=  1000 then
            res(1)      := ' ';
            res(2)      := ints(4);
            res(3)      := '.';
            res(4 to 6) := ints(5 to 7);
        else
            report "Unexpectedly low value for frq (below 1Hz ?)" severity error;
        end if;
        return (res);
    end function FreqImage;




    --    ###   ####   ###         #   #    ##
    --   #   #  #   #   #          #   #   #  #
    --   #      #   #   #           # #    #      ###   # ##
    --    ###   ####    #            #    ###    #   #  ##  #
    --       #  #       #           # #    #     #####  #
    --   #   #  #       #          #   #   #     #      #
    --    ###   #      ###  #####  #   #   #      ###   #
    --
    -- actually performs a fake SPI transfer
    procedure SPI_Xfer(constant value   : in std_logic_vector(BITS_PER_WORD-1 downto 0);    -- value sent by master
                       constant period  : in time;                                          -- SPI clock period
                       constant rise_SS : in integer;                                       -- = 0 : SS is not raised at end of transfer
                                                                                            -- > 0 : number of half periods befor rising SS)
                                                                                            -- > 2*BITS_PER_WORD : normal transfer with SS raised at the end

                       signal   SS     : out std_logic;                                     -- SPI SS   signal
                       signal   SCK    : out std_logic;                                     -- SPI SCK  signal
                       signal   MOSI   : out std_logic;                                     -- SPI MOSI signal
                       signal   MISO   : in  std_logic;                                     -- SPI MISO signal

                       signal   resp   : out std_logic_vector(BITS_PER_WORD-1 downto 0)) is -- resp is the data returned by slave

        variable rxreg      : std_logic_vector(BITS_PER_WORD-1 downto 0);   -- used to build resp without modifying it at each bit reception
        variable period_cnt : integer;                                      -- necessary to manage bit ordering
        variable locval     : std_logic_vector(BITS_PER_WORD-1 downto 0);   -- local copy of data to send
    begin
        if MSB_FIRST = 0 then
            for i in 0 to BITS_PER_WORD-1 loop
                locval(i) := value(BITS_PER_WORD-1-i);
            end loop;
        else
            locval := value;
        end if;

        SS <= '0';

        for i in 1 to BITS_PER_WORD loop
            period_cnt := BITS_PER_WORD - i;

            if rise_SS > i*2-2 or rise_SS = 0 then
                case SPI_MODE is
                    when      0 => SCK <= '0'; MOSI <= locval(period_cnt);
                    when      1 => SCK <= '0';
                    when      2 => SCK <= '1'; MOSI <= locval(period_cnt);
                    when      3 => SCK <= '1';
                end case;
            end if;

            if rise_SS > i*2-1 or rise_SS = 0  then
                wait for period/2;

                case SPI_MODE is
                    when      0 => SCK <= '1'; rxreg(period_cnt) := MISO;
                    when      1 => SCK <= '1'; MOSI <= locval(period_cnt);
                    when      2 => SCK <= '0'; rxreg(period_cnt) := MISO;
                    when      3 => SCK <= '0'; MOSI <= locval(period_cnt);
                end case;
            end if;

            if rise_SS > i*2 or rise_SS = 0  then
                wait for period/2;

                case SPI_MODE is
                    when      1 => rxreg(period_cnt) := MISO;
                    when      3 => rxreg(period_cnt) := MISO;
                    when others => null;
                end case;
            end if;

            --report "bit " & integer'image(period_cnt) & ", " & BinImage(rxreg);
        end loop;

        if rise_SS > BITS_PER_WORD*2 or rise_SS = 0  then
            case SPI_MODE is
                when      0 => SCK <= '0';
                when      1 => SCK <= '0';
                when      2 => SCK <= '1';
                when      3 => SCK <= '1';
            end case;
        end if;

        wait for 1 fs;
        if MSB_FIRST = 0 then
            for i in 0 to BITS_PER_WORD-1 loop
                resp(i) <= rxreg(BITS_PER_WORD-1-i);
            end loop;
        else
            resp <= rxreg;
        end if;



        if rise_SS > 0 then
            case SPI_MODE is
                when      0 => MOSI <= 'Z';
                when      1 => null;
                when      2 => MOSI <= 'Z';
                when      3 => null;
            end case;

            wait for period/2;
            SS   <= '1';
            MOSI <= 'Z';
            wait for period/2;
        end if;
    end procedure;



    --    ###   #                    #                              #          ###   ##
    --   #   #  #                    #                              #         #   #   #
    --   #      # ##    ###    ###   #  #          ###   # ##    ## #         #       #    ###    ###   # ##           ###   # ##   # ##
    --   #      ##  #  #   #  #   #  # #              #  ##  #  #  ##         #       #   #   #      #  ##  #         #   #  ##  #  ##  #
    --   #      #   #  #####  #      ##            ####  #   #  #   #         #       #   #####   ####  #             #####  #      #
    --   #   #  #   #  #      #      # #          #   #  #   #  #   #         #   #   #   #      #   #  #             #      #      #
    --    ###   #   #   ###    ####  #  #  #####   ####  #   #   ####  #####   ###   ###   ###    ####  #      #####   ###   #      #
    --
    -- this is to lighten test code.
    -- checks an error signal and clears it afterwards
    procedure check_and_clear_err(constant expected : in  boolean;
                                  constant err_name : in  string;
                                  signal   status   : in  std_logic;
                                  signal   clearsig : out std_logic) is
    begin
        if expected then
            assert status = '1' report err_name & " error should have been set";
        else
            assert status = '0' report err_name & " error unexpectedly asserted";
        end if;
        clearsig <= '1';
        wait for 1 fs;
        clearsig <= '0';
    end procedure;


--    ###    #                        ##        ###                  ##                         #      #
--   #   #                             #        #  #                  #                         #
--   #      ##    ###   # ##    ###    #        #   #   ###    ###    #    ###   # ##    ###   ####   ##    ###   # ##    ####
--    ###    #   #   #  ##  #      #   #        #   #  #   #  #   #   #       #  ##  #      #   #      #   #   #  ##  #  #
--       #   #   #  ##  #   #   ####   #        #   #  #####  #       #    ####  #       ####   #      #   #   #  #   #   ###
--   #   #   #    ## #  #   #  #   #   #        #  #   #      #       #   #   #  #      #   #   #  #   #   #   #  #   #      #
--    ###   ###      #  #   #   ####  ###       ###     ###    ####  ###   ####  #       ####    ##   ###   ###   #   #  ####
--                ###

    signal clk                 : std_logic;
    signal reset               : std_logic := '1';
    signal SPI_SS              : std_logic := '1';
    signal SPI_SCK             : std_logic := '0';
    signal SPI_MOSI            : std_logic := 'Z';
    signal SPI_MISO            : std_logic;
    signal data_from_master    : std_logic_vector(BITS_PER_WORD - 1 downto 0);
    signal data_from_master_en : std_logic;
    signal data_from_master_rd : std_logic;
    signal data_to_master      : std_logic_vector(BITS_PER_WORD - 1 downto 0);
    signal data_to_master_en   : std_logic;
    signal data_to_master_rd   : std_logic;
    signal err_dropped_data_in : std_logic;
    --signal err_sent_default    : std_logic;


    signal clk_en       : boolean := True;                              -- should the clock run ?
    signal dut_sent     : std_logic_vector(BITS_PER_WORD-1 downto 0);   -- data sent by dut
    signal dut_recv     : std_logic_vector(BITS_PER_WORD-1 downto 0);   -- data received by dut
    signal new_dut_recv : std_logic := '0';                             -- dut_recv has been updated
    signal ndutrecv_set : std_logic;                                    -- set new_dut_recv
    signal ndutrecv_clr : std_logic;                                    -- clear new_dut_recv
    signal inhibit_rcv  : std_logic := '0';                             -- to test behavior on read errors : inhibit data read

    signal err_TX_happend : std_logic := '0';                           -- did err_sent_default happen ?
    signal err_TX_set     : std_logic;                                  -- set err_TX_happend
    signal err_TX_reset   : std_logic;                                  -- clear err_TX_happend

    signal err_RX_happend : std_logic := '0';                           -- did err_dropped_data_in happen ?
    signal err_RX_reset   : std_logic;                                  -- clear err_RX_happend

begin

--   ###    #   #  #####        #                  #                           #           #      #
--   #  #   #   #    #                             #                                       #
--   #   #  #   #    #         ##   # ##    ####  ####    ###   # ##    ###   ##    ###   ####   ##    ###   # ##
--   #   #  #   #    #          #   ##  #  #       #         #  ##  #  #   #   #       #   #      #   #   #  ##  #
--   #   #  #   #    #          #   #   #   ###    #      ####  #   #  #       #    ####   #      #   #   #  #   #
--   #  #   #   #    #          #   #   #      #   #  #  #   #  #   #  #       #   #   #   #  #   #   #   #  #   #
--   ###     ###     #         ###  #   #  ####     ##    ####  #   #   ####  ###   ####    ##   ###   ###   #   #
--

    non_synthetizable : if model > 0 generate
        dut : entity work.SPI_slave_SimModel
        Generic map(SPI_MODE      => SPI_MODE,
                    MSB_FIRST     => MSB_FIRST_GEN(0),
                    BITS_PER_WORD => BITS_PER_WORD,
                    DEFAULT_VALUE => DEFAULT_GEN,
                    DROP_NEW_DAT  => DROP_NEW_DAT_GEN(0))
            port map(
                    clk                 => clk,
                    reset               => reset,
                    SPI_SS              => SPI_SS,
                    SPI_SCK             => SPI_SCK,
                    SPI_MOSI            => SPI_MOSI,
                    SPI_MISO            => SPI_MISO,
                    data_from_master    => data_from_master,
                    data_from_master_en => data_from_master_en,
                    data_from_master_rd => data_from_master_rd,
                    data_to_master      => data_to_master,
                    data_to_master_en   => data_to_master_en,
                    data_to_master_rd   => data_to_master_rd,
                    err_dropped_data_in => err_dropped_data_in,
                    err_sent_default    => err_TX_set);
    end generate;

    synthetizable : if model = 0 generate
        dut : entity work.SPI_slave
        Generic map(SPI_MODE      => SPI_MODE,
                    MSB_FIRST     => MSB_FIRST_GEN(0),
                    BITS_PER_WORD => BITS_PER_WORD,
                    DEFAULT_VALUE => DEFAULT_GEN,
                    DROP_NEW_DAT  => DROP_NEW_DAT_GEN(0))
            port map(
                    clk                 => clk,
                    reset               => reset,
                    SPI_SS              => SPI_SS,
                    SPI_SCK             => SPI_SCK,
                    SPI_MOSI            => SPI_MOSI,
                    SPI_MISO            => SPI_MISO,
                    data_from_master    => data_from_master,
                    data_from_master_en => data_from_master_en,
                    data_from_master_rd => data_from_master_rd,
                    data_to_master      => data_to_master,
                    data_to_master_en   => data_to_master_en,
                    data_to_master_rd   => data_to_master_rd,
                    err_dropped_data_in => err_dropped_data_in,
                    err_sent_default    => err_TX_set);
    end generate;


--   #####                 #
--     #                   #
--     #     ###    ####  ####         ####   ###    ####  #   #   ###   # ##    ###    ###
--     #    #   #  #       #          #      #   #  #   #  #   #  #   #  ##  #  #   #  #   #
--     #    #####   ###    #           ###   #####  #   #  #   #  #####  #   #  #      #####
--     #    #          #   #  #           #  #       ####  #  ##  #      #   #  #      #
--     #     ###   ####     ##        ####    ###       #   ## #   ###   #   #   ####   ###
--                                                      #

    process
        variable psdata           : std_logic_vector(127 downto 0) := x"FDB97531ECA86420FEDCBA9876543210";
        variable spi_per          : time;
        variable buffered_TX_data : std_logic_vector(BITS_PER_WORD-1 downto 0);
        variable expected_TX_data : std_logic_vector(BITS_PER_WORD-1 downto 0);
    begin
        report "MODEL         : " & integer'image(MODEL);
        report "SPI_MODE      : " & integer'image(SPI_MODE);
        report "MSB_FIRST     : " & integer'image(MSB_FIRST);
        report "BITS_PER_WORD : " & integer'image(BITS_PER_WORD);
        report "DEFAULT_VALUE : " & integer'image(DEFAULT_VALUE);
        report "DROP_NEW_DAT  : " & integer'image(DROP_NEW_DAT);

        -- kind of seed for psdata
        for i in 0 to BITS_PER_WORD + DROP_NEW_DAT*32 + MSB_FIRST*64 + SPI_MODE*128 loop
            psdata := psdata(0) & psdata(127 downto 1);
        end loop;

        reset       <= '1';
        SPI_SS      <= '1';
        wait for clk_period * 3.1;
        reset <= '0';
        wait for clk_period;

        buffered_TX_data := DEFAULT_GEN(BITS_PER_WORD-1 downto 0);

        -- this loop to preload data (or not)
        for rep_loaded in 0 to 1 loop

            -- loop to make a series with SS rise, and another series without SS rise
            for SSrise_bar in 0 to 1 loop
                report "-------------------------------------------------------------";
                report "rep_loaded  = " & integer'image(rep_loaded);
                report "SS  rise    = " & integer'image(1 - SSrise_bar);
                report "-------------------------------------------------------------";

                spi_per := 10 us;
                for i in 0 to 30 loop

                    --report time'image(spi_per);
                    report "SPI clock frequency : " & FreqImage(spi_per);

                    expected_TX_data := buffered_TX_data;
                    if rep_loaded = 1 then
                        assert data_to_master_rd = '1' report "DUT not accepting data";
                        data_to_master    <= psdata(BITS_PER_WORD-1 downto 0);
                        data_to_master_en <= '1';
                        wait until rising_edge(clk);
                        data_to_master_en <= '0';
                        assert data_to_master_rd = '1' report "TX data not accepted";
                        buffered_TX_data := psdata(BITS_PER_WORD-1 downto 0);
                        psdata := psdata(0) & psdata(127 downto 1);
                    else
                        buffered_TX_data := DEFAULT_GEN(BITS_PER_WORD-1 downto 0);
                    end if;


                    SPI_Xfer(psdata(BITS_PER_WORD-1 downto 0), spi_per, (1+2*BITS_PER_WORD)*(1 - SSrise_bar), SPI_SS, SPI_SCK, SPI_MOSI, SPI_MISO, dut_sent);
                    if new_dut_recv = '0' then
                        -- sometimes, SPI_Xfer finishes so fast that dut_recv has not been updated yet...
                        wait until falling_edge(ndutrecv_set);
                    end if;
                    check_and_clear_err(True, "new_dut_recv", new_dut_recv, ndutrecv_clr);
                    assert dut_sent = expected_TX_data report "data corruption on TX, expecting " & BinImage(expected_TX_data) & " got " & BinImage(dut_sent);
                    assert dut_recv = psdata(BITS_PER_WORD-1 downto 0) report "data corruption on RX, expecting " & BinImage(psdata(BITS_PER_WORD-1 downto 0)) & " got " & BinImage(dut_recv);

                    check_and_clear_err(rep_loaded = 0, "send_default", err_TX_happend, err_TX_reset);

                    psdata := psdata(0) & psdata(127 downto 1);
                    spi_per := (2*spi_per + TARGET_SPI_PER)/3;

                end loop;
            end loop;
        end loop;
        wait for clk_period*10;

        report "-------------------------------------------------------------";
        report "now checking data loss on RX flag";
        inhibit_rcv <= '1';
        SPI_Xfer(psdata(BITS_PER_WORD-1 downto 0), 100 ns, 0, SPI_SS, SPI_SCK, SPI_MOSI, SPI_MISO, dut_sent);
        if new_dut_recv = '0' then
            -- sometimes, SPI_Xfer finishes so fast that dut_recv has not been updated yet...
            wait until falling_edge(ndutrecv_set);
        end if;
        assert data_from_master = psdata(BITS_PER_WORD-1 downto 0) report "data corruption on RX, expecting " & BinImage(psdata(BITS_PER_WORD-1 downto 0)) & " got " & BinImage(data_from_master);
        SPI_Xfer(psdata(BITS_PER_WORD+1 downto 2), 100 ns, 1+2*BITS_PER_WORD, SPI_SS, SPI_SCK, SPI_MOSI, SPI_MISO, dut_sent);
        wait until err_RX_happend = '1' for 1 us;
        assert err_RX_happend = '1' report "timeout while waiting for err_dropped_data_in to raise";

        if DROP_NEW_DAT = 0 then
            assert data_from_master = psdata(BITS_PER_WORD+1 downto 2) report "old word kept, expecting " & BinImage(psdata(BITS_PER_WORD+1 downto 2)) & " got " & BinImage(data_from_master);
        else
            assert data_from_master = psdata(BITS_PER_WORD-1 downto 0) report "old word dropped, expecting " & BinImage(psdata(BITS_PER_WORD-1 downto 0)) & " got " & BinImage(data_from_master);
        end if;
        inhibit_rcv <= '0';
        SPI_Xfer(dut_recv, 100 ns, 1+2*BITS_PER_WORD, SPI_SS, SPI_SCK, SPI_MOSI, SPI_MISO, dut_sent);
        wait for clk_period*10;
        check_and_clear_err(True, "err_RX_happend", err_RX_happend, err_RX_reset);
        check_and_clear_err(True, "new_dut_recv", new_dut_recv, ndutrecv_clr);
        check_and_clear_err(True, "send_default", err_TX_happend, err_TX_reset);


        wait for clk_period*10;
        report "-------------------------------------------------------------";
        report "now checking behavior on incomplete transfer";

        assert data_to_master_rd = '1' report "DUT not accepting data";
        data_to_master    <= dut_recv;
        data_to_master_en <= '1';
        wait until rising_edge(clk);
        data_to_master_en <= '0';
        assert data_to_master_rd = '1' report "TX data not accepted";

        for i in 1 to 2*BITS_PER_WORD-2 loop
            SPI_Xfer(dut_recv, 100 ns, i, SPI_SS, SPI_SCK, SPI_MOSI, SPI_MISO, dut_sent);
            wait for 100 ns;
        end loop;
        assert err_TX_happend      = '0' report "err_TX triggered but no transfer occured";
        assert data_to_master_rd   = '0' report "DUT should not accept new data";
        assert data_from_master_en = '0' report "No data received, but data_from_master_en set";

        clk_en <= False;
        report "over";
        wait;
    end process;


--    ###    #       #               #                    #
--   #   #           #               #                    #
--   #      ##    ## #   ###        ####    ###    ####  ####    ####
--    ###    #   #  ##  #   #        #     #   #  #       #     #
--       #   #   #   #  #####        #     #####   ###    #      ###
--   #   #   #   #   #  #            #  #  #          #   #  #      #
--    ###   ###   ####   ###          ##    ###   ####     ##   ####
--

    process
    begin
        data_from_master_rd <= '0';
        ndutrecv_set        <= '0';
        wait until rising_edge(clk) and data_from_master_en = '1';
        ndutrecv_set        <= '1';
        if inhibit_rcv = '0' then
            dut_recv            <= data_from_master;
            data_from_master_rd <= '1';
            wait for 1 fs;
            ndutrecv_set        <= '0';
            wait until rising_edge(clk);
            data_from_master_rd <= '0';
            wait for 1 fs;
            assert data_from_master_en = '0' report "data_en not cleared after read";
        else
            wait for 1 fs;
            ndutrecv_set        <= '0';
            wait until inhibit_rcv = '0';
        end if;
    end process;

    process
    begin
        wait until rising_edge(err_dropped_data_in);
        wait for clk_period + 1 ps;
        assert err_dropped_data_in = '0' report "err_dropped_data_in set for more than 1 clock period";
    end process;

    process
    begin
        wait until rising_edge(err_TX_set);
        wait for clk_period + 1 ps;
        assert err_TX_set = '0' report "err_sent_default set for more than 1 clock period";
    end process;


--    ###    #       #              ####
--   #   #           #              #   #
--   #      ##    ## #   ###        #   #  # ##    ###    ###    ###    ####   ####   ###    ####
--    ###    #   #  ##  #   #       ####   ##  #  #   #  #   #  #   #  #      #      #   #  #
--       #   #   #   #  #####       #      #      #   #  #      #####   ###    ###   #####   ###
--   #   #   #   #   #  #           #      #      #   #  #      #          #      #  #          #
--    ###   ###   ####   ###        #      #       ###    ####   ###   ####   ####    ###   ####
--

    process
    begin
        if not clk_en then
            wait;
        end if;
        clk <= '1';
        wait for clk_period/2;
        clk <= '0';
        wait for clk_period/2;
    end process;



    process(err_TX_set, err_TX_reset)
    begin
        if err_TX_set = '1' then
            err_TX_happend <= '1';
        elsif err_TX_reset = '1' then
            err_TX_happend <= '0';
        end if;
    end process;

    process(ndutrecv_set, ndutrecv_clr)
    begin
        if ndutrecv_set = '1' then
            new_dut_recv <= '1';
        elsif ndutrecv_clr = '1' then
            new_dut_recv <= '0';
        end if;
    end process;


    process(err_RX_reset, err_dropped_data_in)
    begin
        if err_dropped_data_in = '1' then
            err_RX_happend  <= '1';
        elsif err_RX_reset = '1' then
            err_RX_happend <= '0';
        end if;
    end process;



end Behavioral;

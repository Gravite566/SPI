--LOAD ../../HDL_modules/UART_RECV_generic.vhd
--LOAD ../../HDL_modules/UART_SEND_generic.vhd
--LOAD ../../HDL_modules/computer_IF.vhd
--TARGET=NEXYS4
----GENERIC CLK_FREQU=100000000
----GENERIC RGBINV=0
----GENERIC OTHER=75
----CLOCK clk=100
----I/O_PIN clk:E3
----I/O_PIN uart_rx:C4
----I/O_PIN uart_tx:D4
----I/O_PIN led:T8,V9
----I/O_PIN led0_r:K5  led0_g:F13  led0_b:F6
----I/O_PIN btn:T16,R10
----buttons are left and right
--TARGET=NEXYSA7
----GENERIC CLK_FREQU=100000000
----GENERIC RGBINV=0
----CLOCK clk=100
----I/O_PIN clk:E3
----I/O_PIN uart_rx:C4
----I/O_PIN uart_tx:D4
----I/O_PIN led:H17,K15
----I/O_PIN led0_r:N15  led0_g:M16  led0_b:R12
----I/O_PIN btn:M17,P17
----buttons are left and right
--TARGET=CMODA35,CMODA15
----GENERIC CLK_FREQU=12000000
----GENERIC RGBINV=1
----CLOCK clk=12
----I/O_PIN clk:L17
----I/O_PIN uart_rx:J17
----I/O_PIN uart_tx:J18
----I/O_PIN led:A17,C16
----I/O_PIN led0_r:C17  led0_g:B16  led0_b:B17
----I/O_PIN btn:A18,B18


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity toplevel is
    Generic (CLK_FREQU : integer := 12000000;
             SYNTHDATE : integer :=        0;
             SYNTHTIME : integer :=        0;
             GITHASH0  : integer :=        0;
             GITHASH1  : integer :=        0;
             SYNTHREF  : integer :=        0;
             OTHER     : integer :=        0;
             RGBINV    : integer :=        0);
    Port ( clk       : in  STD_LOGIC;
           uart_rx   : in  STD_LOGIC;
           uart_tx   : out STD_LOGIC;
           led       : out STD_LOGIC_VECTOR (1 downto 0);
           led0_r    : out STD_LOGIC;
           led0_g    : out STD_LOGIC;
           led0_b    : out STD_LOGIC;
           btn       : in  STD_LOGIC_VECTOR (1 downto 0));
end toplevel;

architecture Behavioral of toplevel is

    signal btn_s    : STD_LOGIC_VECTOR(1 downto 0);  -- sync  copy of btn
    signal led_i    : STD_LOGIC_VECTOR(1 downto 0);  -- local copy of led

    signal reset    : std_logic;                     -- system reset

    signal RXdat    : STD_LOGIC_VECTOR( 7 downto 0); -- data received from computer
    signal RXen     : STD_LOGIC;                     -- RXdat strobe
    signal TXdat    : STD_LOGIC_VECTOR( 7 downto 0); -- data to send to computer
    signal TXen     : STD_LOGIC;                     -- TXdat strobe
    signal TXbsy    : STD_LOGIC;                     -- Transmit module busy
    signal TXrdy    : STD_LOGIC;                     -- Transmit module ready
    
    signal addr     : STD_LOGIC_VECTOR(15 downto 0); -- local bus addr
    signal d16_wr   : STD_LOGIC_VECTOR(15 downto 0); -- local bus data write
    signal d16_rd   : STD_LOGIC_VECTOR(15 downto 0); -- local bus data read
    
    signal d16_wen  : STD_LOGIC;                     -- local bus write enable
    signal d16_wack : STD_LOGIC;                     -- local bus write acknowledge
    signal d16_ren  : STD_LOGIC;                     -- local bus read enable
    signal d16_rack : STD_LOGIC;                     -- local bus read acknowledge (d_rd strobe)

    signal err_addr : STD_LOGIC;                     -- local bus address error
    
    
    signal pwm_counter : unsigned(16 downto 0);      -- used for PWM on RGB LEDs
    signal pwm_red     : unsigned(15 downto 0);
    signal pwm_green   : unsigned(15 downto 0);
    signal pwm_blue    : unsigned(15 downto 0);

begin

    led <= led_i;

    process(clk)
    begin
        if rising_edge(clk) then
            reset <= btn_s(0) and btn_s(1);
            btn_s <= btn;  
        end if;
    end process;

    uart_in : entity work.UART_RECV_generic
    Generic map (CLK_FREQU => CLK_FREQU,
                 BAUDRATE  =>   921600,
                 TIME_PREC =>      200,
                 DATA_SIZE =>        8)
    Port map( clk   => clk,
              reset => reset,
              RX    => uart_rx,
              dout  => RXdat,
              den   => RXen);

    uart_out : entity work.UART_SEND_generic
    Generic map (CLK_FREQU => CLK_FREQU,
                 BAUDRATE  =>   921600,
                 TIME_PREC =>      200,
                 DATA_SIZE =>        8)
    Port map( clk   => clk,
              reset => reset,
              TX    => uart_tx,
              din   => TXdat,
              den   => TXen,
              bsy   => TXbsy);

    TXrdy <= not TXbsy;
    
    if_mgr : entity work.computer_IF
    Generic map(PROJECT_ID  => x"FFFF",
	            TIMEOUT     => CLK_FREQU/10)
    port map (clk       => clk,
              reset     => reset,
              RXdat     => RXdat,
              RXen      => RXen,
              RXrdy     => open,
              TXdat     => TXdat,
              TXen      => TXen,
              TXrdy     => TXrdy,
              lst_CMD_b => open,

              addr      => addr,
              dout      => d16_wr,
              din       => d16_rd,

              d_wen     => d16_wen,
              d_wack    => d16_wack,
              d_ren     => d16_ren,
              d_rack    => d16_rack,

              p_empty_n => open,
              p_read    => '1',
              p_full_n  => open,
              p_write   => '0',
              p_start   => open, 
              p_stop    => open,

              err_mstmx => '0',
              err_addr  => err_addr);


    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                led_i     <= "00";
                pwm_red   <= to_unsigned(0, 16);
                pwm_green <= to_unsigned(0, 16);
                pwm_blue  <= to_unsigned(0, 16);
                d16_wack  <= '0';
                err_addr  <= '0';
                d16_rd   <= "0000000000000000";
                d16_rack <= '0';
            elsif d16_wen = '1' then
                d16_rd   <= "0000000000000000";
                d16_rack <= '0';
                if unsigned(addr) = 0 then
                    led_i     <= d16_wr(1 downto 0);
                    d16_wack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 1 then
                    pwm_red   <= unsigned(d16_wr);
                    d16_wack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 2 then
                    pwm_green <= unsigned(d16_wr);
                    d16_wack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 3 then
                    pwm_blue  <= unsigned(d16_wr);
                    d16_wack  <= '1';
                    err_addr  <= '0';
                else
                    d16_wack  <= '0';
                    err_addr  <= '1';
                end if;
            elsif d16_ren = '1' then
                d16_wack <= '0';
                if unsigned(addr) = 0 then
                    d16_rd    <= x"00" & "00" & btn_s & "00" & led_i;
                    d16_rack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 1 then
                    d16_rd    <= std_logic_vector(pwm_red);
                    d16_rack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 2 then
                    d16_rd    <= std_logic_vector(pwm_green);
                    d16_rack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 3 then
                    d16_rd    <= std_logic_vector(pwm_blue);
                    d16_rack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 4 then
                    d16_rd    <= std_logic_vector(to_unsigned(SYNTHDATE, 16));
                    d16_rack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 5 then
                    d16_rd    <= std_logic_vector(to_unsigned(SYNTHTIME, 16));
                    d16_rack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 6 then
                    d16_rd    <= std_logic_vector(to_unsigned(GITHASH0, 16));
                    d16_rack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 7 then
                    d16_rd    <= std_logic_vector(to_unsigned(GITHASH1, 16));
                    d16_rack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 8 then
                    d16_rd    <= std_logic_vector(to_unsigned(SYNTHREF, 16));
                    d16_rack  <= '1';
                    err_addr  <= '0';
                elsif unsigned(addr) = 9 then
                    d16_rd    <= std_logic_vector(to_unsigned(OTHER, 16));
                    d16_rack  <= '1';
                    err_addr  <= '0';
                else
                    d16_rack  <= '0';
                    err_addr  <= '1';
                end if;
            else
                d16_rd   <= "0000000000000000";
                d16_wack <= '0';
                d16_rack <= '0';
                err_addr <= '0';         
            end if;
        end if;
    end process;

    

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pwm_counter  <= to_unsigned(0, 17);
            else
                pwm_counter  <= pwm_counter + 1;      
            end if;
            if pwm_counter < pwm_red xor RGBINV=1 then
                led0_r <= '1';
            else
                led0_r <= '0';
            end if;            
            if pwm_counter < pwm_green xor RGBINV=1 then
                led0_g <= '1';
            else
                led0_g <= '0';
            end if;            
            if pwm_counter < pwm_blue xor RGBINV=1 then
                led0_b <= '1';
            else
                led0_b <= '0';
            end if;            
        end if;
    end process;
    


end Behavioral;

--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
 
 
entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(7 downto 0); -- operands and opcode
        btnU    :   in std_logic; -- reset
        btnC    :   in std_logic; -- fsm advance (used as synchronous enable, NOT a clock)
        btnL    :   in std_logic; -- clock divider reset
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;
 
architecture top_basys3_arch of top_basys3 is
 
    -- Component declarations
    component clock_divider is
        generic ( k_DIV : natural := 25000 );  -- ~2 kHz from 100 MHz
        port ( i_clk : in std_logic; i_reset : in std_logic; o_clk : out std_logic );
    end component;
 
    component controller_fsm is
        port (
            i_clk   : in  std_logic;
            i_reset : in  std_logic;
            i_adv   : in  std_logic;   -- synchronous enable (one-cycle pulse), NOT a clock
            o_cycle : out std_logic_vector(3 downto 0)
        );
    end component;
 
    component ALU is
        port ( i_A, i_B  : in  std_logic_vector(7 downto 0);
               i_op      : in  std_logic_vector(2 downto 0);
               o_result  : out std_logic_vector(7 downto 0);
               o_flags   : out std_logic_vector(3 downto 0) );
    end component;
 
    component twos_comp is
        port ( i_bin  : in  std_logic_vector(7 downto 0);
               o_sign : out std_logic;
               o_hund : out std_logic_vector(3 downto 0);
               o_tens : out std_logic_vector(3 downto 0);
               o_ones : out std_logic_vector(3 downto 0) );
    end component;
 
    component sevenseg_decoder is
        port ( i_Hex   : in  std_logic_vector(3 downto 0);
               o_seg_n : out std_logic_vector(6 downto 0) );
    end component;
 
    -- Clock / slow clock
    signal w_slow_clk : std_logic;
 
    -- Button synchronizer and edge detector for btnC
    signal f_btnC_sync  : std_logic_vector(1 downto 0) := "00";
    signal w_btnC_pulse : std_logic;  -- single-cycle high pulse on rising edge of btnC
 
    -- FSM / datapath wires
    signal w_cycle   : std_logic_vector(3 downto 0);
    signal w_regA    : std_logic_vector(7 downto 0) := (others => '0');
    signal w_regB    : std_logic_vector(7 downto 0) := (others => '0');
    signal w_alu_out : std_logic_vector(7 downto 0);
    signal w_flags   : std_logic_vector(3 downto 0);
    signal w_result  : std_logic_vector(7 downto 0) := (others => '0');
 
    -- 7-segment display wires
    signal w_sign     : std_logic;
    signal w_hund, w_tens, w_ones : std_logic_vector(3 downto 0);
    signal w_seg_h, w_seg_t, w_seg_o : std_logic_vector(6 downto 0);
    signal w_display_value : std_logic_vector(7 downto 0);
    signal w_mux_cnt  : unsigned(1 downto 0) := "00";
    signal w_seg_sign : std_logic_vector(6 downto 0);
 
begin
 
    -- PORT MAPS ----------------------------------------
 
    u_clkdiv : clock_divider
        generic map ( k_DIV => 25000 )
        port map ( i_clk => clk, i_reset => btnL, o_clk => w_slow_clk );
 
    -- FSM now receives the real clock and a one-cycle enable pulse
    u_fsm : controller_fsm
        port map (
            i_clk   => clk,
            i_reset => btnU,
            i_adv   => w_btnC_pulse,
            o_cycle => w_cycle
        );
 
    u_alu : ALU
        port map ( i_A => w_regA, i_B => w_regB,
                   i_op => sw(2 downto 0),
                   o_result => w_alu_out, o_flags => w_flags );
 
    u_tc : twos_comp
        port map ( i_bin => w_display_value, o_sign => w_sign,
                   o_hund => w_hund, o_tens => w_tens, o_ones => w_ones );
 
    u_dec_h : sevenseg_decoder port map ( i_Hex => w_hund, o_seg_n => w_seg_h );
    u_dec_t : sevenseg_decoder port map ( i_Hex => w_tens, o_seg_n => w_seg_t );
    u_dec_o : sevenseg_decoder port map ( i_Hex => w_ones, o_seg_n => w_seg_o );
 
 
    -- CONCURRENT STATEMENTS ----------------------------
 
    -- Two-stage synchronizer for btnC to avoid metastability,
    -- followed by rising-edge detection.  Everything is clocked
    -- by the 100 MHz system clock so Vivado sees only one clock domain.
    btnC_sync : process(clk)
    begin
        if rising_edge(clk) then
            f_btnC_sync <= f_btnC_sync(0) & btnC;
        end if;
    end process;
 
    -- Rising-edge pulse: high for exactly one 100 MHz clock cycle
    w_btnC_pulse <= f_btnC_sync(0) and (not f_btnC_sync(1));
 
    -- Register A: latch switches when FSM is in cycle 1 and btnC is pressed
    reg_A : process(clk)
    begin
        if rising_edge(clk) then
            if btnU = '1' then
                w_regA <= (others => '0');
            elsif w_btnC_pulse = '1' and w_cycle = "0001" then
                w_regA <= sw;
            end if;
        end if;
    end process;
 
    -- Register B: latch switches when FSM is in cycle 2 and btnC is pressed
    reg_B : process(clk)
    begin
        if rising_edge(clk) then
            if btnU = '1' then
                w_regB <= (others => '0');
            elsif w_btnC_pulse = '1' and w_cycle = "0010" then
                w_regB <= sw;
            end if;
        end if;
    end process;
 
    -- Result register: latch ALU output when FSM is in cycle 3 and btnC is pressed
    reg_result : process(clk)
    begin
        if rising_edge(clk) then
            if btnU = '1' then
                w_result <= (others => '0');
            elsif w_btnC_pulse = '1' and w_cycle = "0100" then
                w_result <= w_alu_out;
            end if;
        end if;
    end process;
 
    -- 7-seg digit-mux counter (driven by slow clock)
    mux_counter : process(w_slow_clk)
    begin
        if rising_edge(w_slow_clk) then
            w_mux_cnt <= w_mux_cnt + 1;
        end if;
    end process;
 
    -- Sign digit: '-' segment pattern when negative, blank when positive
    w_seg_sign <= "0111111" when w_sign = '1' else "1111111";
 
    -- Display mux: choose which value to decode based on current FSM cycle
    w_display_value <= w_regA   when w_cycle = "0010" else  -- A just loaded
                       w_regB   when w_cycle = "0100" else  -- B just loaded
                       w_result when w_cycle = "1000" else  -- result latched
                       (others => '0');
 
    -- Active-low anode enables (one digit at a time)
    with w_mux_cnt select
        an <= "1110" when "00",   -- ones  (rightmost)
              "1101" when "01",   -- tens
              "1011" when "10",   -- hundreds
              "0111" when "11",   -- sign  (leftmost)
              "1111" when others;
 
    -- Segment pattern fed to whichever digit is currently active
    with w_mux_cnt select
        seg <= w_seg_o    when "00",
               w_seg_t    when "01",
               w_seg_h    when "10",
               w_seg_sign when "11",
               "1111111"  when others;
 
    -- LEDs: cycle state on bottom 4, NZCV flags on top 4
    led(3 downto 0)   <= w_cycle;
    led(11 downto 4)  <= (others => '0');
    led(15 downto 12) <= w_flags;
 
end top_basys3_arch;
 
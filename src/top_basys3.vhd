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
        clk     : in  std_logic;
        sw      : in  std_logic_vector(7 downto 0);
        btnU    : in  std_logic; -- reset
        btnC    : in  std_logic; -- fsm advance
        btnL    : in  std_logic; -- clock divider reset
        -- outputs
        led     : out std_logic_vector(15 downto 0);
        seg     : out std_logic_vector(6 downto 0);
        an      : out std_logic_vector(3 downto 0)
    );
end top_basys3;
 
architecture top_basys3_arch of top_basys3 is
 
    component clock_divider is
        generic ( k_DIV : natural := 25000 );
        port ( i_clk : in std_logic; i_reset : in std_logic; o_clk : out std_logic );
    end component;
 
    component controller_fsm is
        port (
            i_clk   : in  std_logic;
            i_reset : in  std_logic;
            i_adv   : in  std_logic;
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
 
    component TDM4 is
        generic ( constant k_WIDTH : natural := 4 );
        port ( i_clk   : in  std_logic;
               i_reset : in  std_logic;
               i_D3    : in  std_logic_vector(k_WIDTH - 1 downto 0);
               i_D2    : in  std_logic_vector(k_WIDTH - 1 downto 0);
               i_D1    : in  std_logic_vector(k_WIDTH - 1 downto 0);
               i_D0    : in  std_logic_vector(k_WIDTH - 1 downto 0);
               o_data  : out std_logic_vector(k_WIDTH - 1 downto 0);
               o_sel   : out std_logic_vector(3 downto 0) );
    end component;
 
    -- Clocks
    signal w_slow_clk : std_logic;
 
    -- Button synchronizer / edge detector
    signal f_btnC_sync  : std_logic_vector(1 downto 0) := "00";
    signal w_btnC_pulse : std_logic;
 
    -- FSM / datapath
    signal w_cycle   : std_logic_vector(3 downto 0);
    signal w_regA    : std_logic_vector(7 downto 0) := (others => '0');
    signal w_regB    : std_logic_vector(7 downto 0) := (others => '0');
    signal w_alu_out : std_logic_vector(7 downto 0);
    signal w_flags   : std_logic_vector(3 downto 0);
    signal w_result  : std_logic_vector(7 downto 0) := (others => '0');
 
    -- twos_comp outputs
    signal w_sign : std_logic;
    signal w_hund, w_tens, w_ones : std_logic_vector(3 downto 0);
 
    -- Sign digit: "0001" = '-' pattern, "1111" = blank
    -- Encoded as 4-bit to feed into TDM4 (which feeds sevenseg_decoder)
    signal w_sign_digit : std_logic_vector(3 downto 0);
 
    -- TDM4 outputs
    signal w_tdm_data : std_logic_vector(3 downto 0);
 
    -- Display value fed into twos_comp
    signal w_display_value : std_logic_vector(7 downto 0);
 
begin
 
    -- PORT MAPS ----------------------------------------
 
    u_clkdiv : clock_divider
        generic map ( k_DIV => 25000 )
        port map ( i_clk => clk, i_reset => btnL, o_clk => w_slow_clk );
 
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
        port map ( i_bin => w_display_value,
                   o_sign => w_sign,
                   o_hund => w_hund,
                   o_tens => w_tens,
                   o_ones => w_ones );
 
    -- TDM4 cycles through: sign(D3), hundreds(D2), tens(D1), ones(D0)
    -- o_sel drives 'an' directly (already one-cold active-low)
    u_tdm : TDM4
        generic map ( k_WIDTH => 4 )
        port map (
            i_clk   => w_slow_clk,
            i_reset => btnL,
            i_D3    => w_sign_digit,  -- leftmost digit
            i_D2    => w_hund,
            i_D1    => w_tens,
            i_D0    => w_ones,        -- rightmost digit
            o_data  => w_tdm_data,
            o_sel   => an
        );
 
    -- Single sevenseg_decoder driven by whichever digit TDM4 selects
    u_seg : sevenseg_decoder
        port map ( i_Hex => w_tdm_data, o_seg_n => seg );
 
 
    -- CONCURRENT STATEMENTS ----------------------------
 
    -- btnC two-stage synchronizer + rising-edge detector
    btnC_sync : process(clk)
    begin
        if rising_edge(clk) then
            f_btnC_sync <= f_btnC_sync(0) & btnC;
        end if;
    end process;
 
    w_btnC_pulse <= f_btnC_sync(0) and (not f_btnC_sync(1));
 
    -- Register A
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
 
    -- Register B
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
 
    -- Result register
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
 
    -- Choose what value to display based on FSM cycle
    w_display_value <= w_regA   when w_cycle = "0010" else
                       w_regB   when w_cycle = "0100" else
                       w_result when w_cycle = "1000" else
                       (others => '0');
 
    
    w_sign_digit <= "1110" when w_sign = '1' else  -- '-' (E slot repurposed)
                    "1111";                          -- blank (F slot repurposed)
 
    -- LEDs
    led(3 downto 0)   <= w_cycle;
    led(11 downto 4)  <= (others => '0');
    led(15 downto 12) <= w_flags;
 
end top_basys3_arch;
 
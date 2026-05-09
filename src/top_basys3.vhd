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
        clk     : in  std_logic;
        sw      : in  std_logic_vector(7 downto 0);
        btnU    : in  std_logic;
        btnC    : in  std_logic;
        btnL    : in  std_logic;
        led     : out std_logic_vector(15 downto 0);
        seg     : out std_logic_vector(6 downto 0);
        an      : out std_logic_vector(3 downto 0)
    );
end top_basys3;
 
architecture top_basys3_arch of top_basys3 is
 
    component clock_divider is
        generic ( constant k_DIV : natural := 2 );
        port ( i_clk   : in  std_logic;
               i_reset : in  std_logic;
               o_clk   : out std_logic );
    end component;
 
    component controller_fsm is
        port ( i_clk   : in  std_logic;
               i_reset : in  std_logic;
               i_adv   : in  std_logic;
               o_cycle : out std_logic_vector(3 downto 0) );
    end component;
 
    component ALU is
        port ( i_A     : in  std_logic_vector(7 downto 0);
               i_B     : in  std_logic_vector(7 downto 0);
               i_op    : in  std_logic_vector(2 downto 0);
               o_result: out std_logic_vector(7 downto 0);
               o_flags : out std_logic_vector(3 downto 0) );
    end component;
 
    component twos_comp is
        port ( i_bin  : in  std_logic_vector(7 downto 0);
               o_sign : out std_logic;
               o_hund : out std_logic_vector(3 downto 0);
               o_tens : out std_logic_vector(3 downto 0);
               o_ones : out std_logic_vector(3 downto 0) );
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
 
    component sevenseg_decoder is
        port ( i_Hex   : in  std_logic_vector(3 downto 0);
               o_seg_n : out std_logic_vector(6 downto 0) );
    end component;
 
    signal w_clk_tdm : std_logic;
    signal w_cycle   : std_logic_vector(3 downto 0);
 
    signal f_A : std_logic_vector(7 downto 0) := (others => '0');
    signal f_B : std_logic_vector(7 downto 0) := (others => '0');
 
    signal w_alu_result : std_logic_vector(7 downto 0);
    signal w_flags      : std_logic_vector(3 downto 0);
 
    signal w_display : std_logic_vector(7 downto 0);
 
    signal w_sign : std_logic;
    signal w_hund : std_logic_vector(3 downto 0);
    signal w_tens : std_logic_vector(3 downto 0);
    signal w_ones : std_logic_vector(3 downto 0);
 
    signal w_tdm_data  : std_logic_vector(3 downto 0);
    signal w_tdm_sel   : std_logic_vector(3 downto 0);
 
    signal w_seg_raw   : std_logic_vector(6 downto 0);
    signal w_sign_digit: std_logic_vector(3 downto 0);
 
    signal f_btnC_count  : integer range 0 to 1000000 := 0;
    signal f_btnC_stable : std_logic := '0';
    signal f_btnC_prev   : std_logic := '0';
    signal w_btnC_rise   : std_logic;
 
begin
 
    -- Button debounce
    debounce : process(clk)
    begin
        if rising_edge(clk) then
            if btnU = '1' then
                f_btnC_count  <= 0;
                f_btnC_stable <= '0';
                f_btnC_prev   <= '0';
            else
                if btnC = '1' then
                    if f_btnC_count = 1000000 then
                        f_btnC_stable <= '1';
                    else
                        f_btnC_count <= f_btnC_count + 1;
                    end if;
                else
                    f_btnC_count  <= 0;
                    f_btnC_stable <= '0';
                end if;
                f_btnC_prev <= f_btnC_stable;
            end if;
        end if;
    end process;
 
    w_btnC_rise <= '1' when (f_btnC_stable = '1' and f_btnC_prev = '0') else '0';
 
    u_clkdiv : clock_divider
        generic map ( k_DIV => 50000 )
        port map ( i_clk => clk, i_reset => btnU, o_clk => w_clk_tdm );
 
    u_fsm : controller_fsm
        port map ( i_clk => clk, i_reset => btnU,
                   i_adv => w_btnC_rise, o_cycle => w_cycle );
 
    u_alu : ALU
        port map ( i_A => f_A, i_B => f_B, i_op => sw(2 downto 0),
                   o_result => w_alu_result, o_flags => w_flags );
 
    u_twos : twos_comp
        port map ( i_bin => w_display, o_sign => w_sign,
                   o_hund => w_hund, o_tens => w_tens, o_ones => w_ones );
 
    u_tdm : TDM4
        generic map ( k_WIDTH => 4 )
        port map ( i_clk => w_clk_tdm, i_reset => btnU,
                   i_D3 => w_sign_digit, i_D2 => w_hund,
                   i_D1 => w_tens,       i_D0 => w_ones,
                   o_data => w_tdm_data, o_sel => w_tdm_sel );
 
    u_seg : sevenseg_decoder
        port map ( i_Hex => w_tdm_data, o_seg_n => w_seg_raw );
 
    -- Registers
    register_process : process(clk)
    begin
        if rising_edge(clk) then
            if btnU = '1' then
                f_A <= (others => '0');
                f_B <= (others => '0');
            elsif w_btnC_rise = '1' then
                if w_cycle = "0001" then f_A <= sw; end if;
                if w_cycle = "0010" then f_B <= sw; end if;
            end if;
        end if;
    end process;
 
    -- Display value mux
    w_display <= (others => '0') when w_cycle = "0001" else
                 f_A             when w_cycle = "0010" else
                 f_B             when w_cycle = "0100" else
                 w_alu_result    when w_cycle = "1000" else
                 (others => '0');
 
    -- "A" (x"A") in sevenseg_decoder renders the dash segment pattern
    w_sign_digit <= "1010" when w_sign = '1' else "1111";
 
    -- Override seg to show '-' on leftmost digit when negative
    seg <= "1111110" when (w_sign = '1' and w_tdm_sel = "0111") else
           w_seg_raw;
 
    -- Blank leftmost digit when positive; blank all when cycle 1
    an <= "1111" when w_cycle = "0001" else
          "1111" when (w_sign = '0' and w_tdm_sel = "0111") else
          w_tdm_sel;
 
    led(3 downto 0)   <= w_cycle;
    led(11 downto 4)  <= (others => '0');
    led(15 downto 12) <= w_flags;
 
end top_basys3_arch;
 
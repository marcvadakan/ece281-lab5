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
        btnC    :   in std_logic; -- fsm cycle
        
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;
 
architecture top_basys3_arch of top_basys3 is
  
	-- declare components and signals
 
    component controller_fsm is
        Port ( i_clk   : in  STD_LOGIC;
               i_reset : in  STD_LOGIC;
               i_adv   : in  STD_LOGIC;
               o_cycle : out STD_LOGIC_VECTOR (3 downto 0));
    end component controller_fsm;
 
    component ALU is
        Port ( i_A      : in  STD_LOGIC_VECTOR (7 downto 0);
               i_B      : in  STD_LOGIC_VECTOR (7 downto 0);
               i_op     : in  STD_LOGIC_VECTOR (2 downto 0);
               o_result : out STD_LOGIC_VECTOR (7 downto 0);
               o_flags  : out STD_LOGIC_VECTOR (3 downto 0));
    end component ALU;
 
    component clock_divider is
        generic ( constant k_DIV : natural := 2 );
        port ( i_clk   : in  std_logic;
               i_reset : in  std_logic;
               o_clk   : out std_logic);
    end component clock_divider;
 
    component TDM4 is
        generic ( constant k_WIDTH : natural := 4 );
        Port ( i_clk   : in  STD_LOGIC;
               i_reset : in  STD_LOGIC;
               i_D3    : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
               i_D2    : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
               i_D1    : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
               i_D0    : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
               o_data  : out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
               o_sel   : out STD_LOGIC_VECTOR (3 downto 0));
    end component TDM4;
 
    component twos_comp is
        port ( i_bin  : in  std_logic_vector(7 downto 0);
               o_sign : out std_logic;
               o_hund : out std_logic_vector(3 downto 0);
               o_tens : out std_logic_vector(3 downto 0);
               o_ones : out std_logic_vector(3 downto 0));
    end component twos_comp;
 
    component sevenseg_decoder is
        port ( i_sel : in  std_logic_vector(3 downto 0);
               o_D   : out std_logic_vector(6 downto 0));
    end component sevenseg_decoder;
 
    constant k_DIV       : natural := 50000;
 
    signal w_cycle       : std_logic_vector(3 downto 0);
    signal f_A           : std_logic_vector(7 downto 0) := (others => '0');
    signal f_B           : std_logic_vector(7 downto 0) := (others => '0');
    signal w_alu_result  : std_logic_vector(7 downto 0);
    signal w_alu_flags   : std_logic_vector(3 downto 0);
    signal w_display_val : std_logic_vector(7 downto 0);
    signal w_sign        : std_logic;
    signal w_hund        : std_logic_vector(3 downto 0);
    signal w_tens        : std_logic_vector(3 downto 0);
    signal w_ones        : std_logic_vector(3 downto 0);
    signal w_clk_tdm     : std_logic;
    signal w_tdm_data    : std_logic_vector(3 downto 0);
    signal w_tdm_sel     : std_logic_vector(3 downto 0);
    signal w_seg_raw     : std_logic_vector(6 downto 0);
 
    constant k_MINUS     : std_logic_vector(6 downto 0) := "1111110";
    constant k_BLANK     : std_logic_vector(6 downto 0) := "1111111";
  
begin
	-- PORT MAPS ----------------------------------------
 
    u_FSM : controller_fsm
        port map (
            i_clk   => clk,
            i_reset => btnU,
            i_adv   => btnC,
            o_cycle => w_cycle
        );
 
    reg_proc : process(clk)
    begin
        if rising_edge(clk) then
            if btnU = '1' then
                f_A <= (others => '0');
                f_B <= (others => '0');
            else
                if w_cycle(1) = '1' then
                    f_A <= sw(7 downto 0);
                end if;
                if w_cycle(2) = '1' then
                    f_B <= sw(7 downto 0);
                end if;
            end if;
        end if;
    end process reg_proc;
 
    u_ALU : ALU
        port map (
            i_A      => f_A,
            i_B      => f_B,
            i_op     => sw(2 downto 0),
            o_result => w_alu_result,
            o_flags  => w_alu_flags
        );
 
    u_TWOS : twos_comp
        port map (
            i_bin  => w_display_val,
            o_sign => w_sign,
            o_hund => w_hund,
            o_tens => w_tens,
            o_ones => w_ones
        );
 
    u_CLK_DIV : clock_divider
        generic map ( k_DIV => k_DIV )
        port map (
            i_clk   => clk,
            i_reset => btnU,
            o_clk   => w_clk_tdm
        );
 
    u_TDM4 : TDM4
        generic map ( k_WIDTH => 4 )
        port map (
            i_clk   => w_clk_tdm,
            i_reset => btnU,
            i_D3    => "0000",
            i_D2    => w_hund,
            i_D1    => w_tens,
            i_D0    => w_ones,
            o_data  => w_tdm_data,
            o_sel   => w_tdm_sel
        );
 
    u_SEG : sevenseg_decoder
        port map (
            i_sel => w_tdm_data,
            o_D   => w_seg_raw
        );
 
	-- CONCURRENT STATEMENTS ----------------------------
 
    w_display_val <= f_A          when w_cycle(1) = '1' else
                     f_B          when w_cycle(2) = '1' else
                     w_alu_result when w_cycle(3) = '1' else
                     (others => '0');
 
    seg <= k_BLANK   when w_cycle(0) = '1'                        else
           k_MINUS   when (w_tdm_sel = "0111" and w_sign = '1')   else
           k_BLANK   when (w_tdm_sel = "0111" and w_sign = '0')   else
           w_seg_raw;
 
    an <= "1111" when w_cycle(0) = '1' else w_tdm_sel;
 
    led(3 downto 0)   <= w_cycle;
    led(15 downto 12) <= w_alu_flags;
    led(11 downto 4)  <= (others => '0');
 
end top_basys3_arch;

----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/18/2025 02:42:49 PM
-- Design Name: 
-- Module Name: controller_fsm - FSM
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity controller_fsm is
    Port ( i_clk   : in STD_LOGIC;
           i_reset : in STD_LOGIC;
           i_adv   : in STD_LOGIC;
           o_cycle : out STD_LOGIC_VECTOR (3 downto 0));
end controller_fsm;
 
architecture FSM of controller_fsm is
 
    type sm_cycle is (s_CLEAR, s_OP1, s_OP2, s_RESULT);
    signal f_state    : sm_cycle := s_CLEAR;
    signal f_adv_prev : std_logic := '0';
 
begin
 
    state_reg_proc : process(i_clk, i_reset)
    begin
        if i_reset = '1' then
            f_state    <= s_CLEAR;
            f_adv_prev <= '0';
        elsif rising_edge(i_clk) then
            f_adv_prev <= i_adv;
            if (i_adv = '1' and f_adv_prev = '0') then
                case f_state is
                    when s_CLEAR  => f_state <= s_OP1;
                    when s_OP1    => f_state <= s_OP2;
                    when s_OP2    => f_state <= s_RESULT;
                    when s_RESULT => f_state <= s_CLEAR;
                    when others   => f_state <= s_CLEAR;
                end case;
            end if;
        end if;
    end process state_reg_proc;
 
    with f_state select
        o_cycle <= "0001" when s_CLEAR,
                   "0010" when s_OP1,
                   "0100" when s_OP2,
                   "1000" when s_RESULT,
                   "0001" when others;
 
end FSM;
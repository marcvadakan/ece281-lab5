----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/18/2025 02:50:18 PM
-- Design Name: 
-- Module Name: ALU - Behavioral
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
 
entity ALU is
    Port ( i_A : in STD_LOGIC_VECTOR (7 downto 0);
           i_B : in STD_LOGIC_VECTOR (7 downto 0);
           i_op : in STD_LOGIC_VECTOR (2 downto 0);
           o_result : out STD_LOGIC_VECTOR (7 downto 0);
           o_flags : out STD_LOGIC_VECTOR (3 downto 0));
end ALU;
 
architecture Behavioral of ALU is
 
    signal c_sum     : unsigned(8 downto 0);
    signal c_result  : std_logic_vector(7 downto 0);
    signal c_N       : std_logic;
    signal c_Z       : std_logic;
    signal c_C       : std_logic;
    signal c_V       : std_logic;
 
begin
 
    alu_proc : process(i_A, i_B, i_op)
        variable v_A   : unsigned(8 downto 0);
        variable v_B   : unsigned(8 downto 0);
        variable v_sum : unsigned(8 downto 0);
        variable v_res : std_logic_vector(7 downto 0);
    begin
        v_A := unsigned('0' & i_A);
        v_B := unsigned('0' & i_B);
 
        v_res := (others => '0');
        c_C   <= '0';
        c_V   <= '0';
 
        case i_op is
            when "000" =>
                v_sum := v_A + v_B;
                v_res := std_logic_vector(v_sum(7 downto 0));
                c_C   <= v_sum(8);
                c_V   <= (not i_A(7) and not i_B(7) and v_res(7)) or
                          (i_A(7) and i_B(7) and not v_res(7));
 
            when "001" =>
                v_sum := v_A - v_B;
                v_res := std_logic_vector(v_sum(7 downto 0));
                c_C   <= v_sum(8);
                c_V   <= (not i_A(7) and i_B(7) and v_res(7)) or
                          (i_A(7) and not i_B(7) and not v_res(7));
 
            when "010" =>
                v_res := i_A and i_B;
 
            when "011" =>
                v_res := i_A or i_B;
 
            when others =>
                v_res := (others => '0');
        end case;
 
        c_result <= v_res;
    end process alu_proc;
 
    c_N <= c_result(7);
    c_Z <= '1' when c_result = "00000000" else '0';
 
    o_result <= c_result;
    o_flags  <= c_N & c_Z & c_C & c_V;
 
end Behavioral;
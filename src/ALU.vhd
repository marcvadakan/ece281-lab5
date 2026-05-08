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
    Port (
        i_A      : in  STD_LOGIC_VECTOR (7 downto 0);
        i_B      : in  STD_LOGIC_VECTOR (7 downto 0);
        i_op     : in  STD_LOGIC_VECTOR (2 downto 0);
        o_result : out STD_LOGIC_VECTOR (7 downto 0);
        o_flags  : out STD_LOGIC_VECTOR (3 downto 0)  -- N Z C V
    );
end ALU;
 
architecture Behavioral of ALU is
    -- 9-bit signals to capture carry-out in bit 8
    signal w_A    : unsigned(8 downto 0);
    signal w_B_in : unsigned(8 downto 0);   -- B (add) or ~B (sub)
    signal w_cin  : unsigned(8 downto 0);   -- 0 (add) or 1 (sub)
    signal w_sum  : unsigned(8 downto 0);
 
    signal w_and    : std_logic_vector(7 downto 0);
    signal w_or     : std_logic_vector(7 downto 0);
    signal w_result : std_logic_vector(7 downto 0);
 
    signal w_N, w_Z, w_C, w_V : std_logic;
begin
 
    w_A <= '0' & unsigned(i_A);
 
    w_B_in <= '0' & unsigned(not i_B) when i_op = "001"
              else '0' & unsigned(i_B);
 
    w_cin  <= to_unsigned(1, 9) when i_op = "001"
              else to_unsigned(0, 9);
 
    w_sum <= w_A + w_B_in + w_cin;
 
    w_and <= i_A and i_B;
    w_or  <= i_A or  i_B;
 
    with i_op select
        w_result <= std_logic_vector(w_sum(7 downto 0)) when "000",   -- add
                    std_logic_vector(w_sum(7 downto 0)) when "001",   -- subtract
                    w_and                               when "010",   -- AND
                    w_or                                when "011",   -- OR
                    (others => '0')                     when others;
 
    o_result <= w_result;
 
    w_N <= w_result(7);
    w_Z <= '1' when w_result = "00000000" else '0';
    w_C <= w_sum(8);
    w_V <= (i_A(7) xor w_result(7)) and (w_B_in(7) xor w_result(7))
           when (i_op = "000" or i_op = "001")
           else '0';
 
    o_flags <= w_N & w_Z & w_C & w_V;
 
end Behavioral;
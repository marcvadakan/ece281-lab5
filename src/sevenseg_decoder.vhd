library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sevenseg_decoder is
    Port ( i_Hex   : in  STD_LOGIC_VECTOR (3 downto 0);
           o_seg_n : out STD_LOGIC_VECTOR (6 downto 0));
end sevenseg_decoder;

architecture Behavioral of sevenseg_decoder is
    signal w_seg_n : std_logic_vector(6 downto 0);
begin
    with i_Hex select
    w_seg_n <= "0000001" when x"0",
               "1001111" when x"1",
               "0010010" when x"2",
               "0000110" when x"3",
               "1001100" when x"4",
               "0100100" when x"5",
               "0100000" when x"6",
               "0001111" when x"7",
               "0000000" when x"8",
               "0001100" when x"9",
               "0001000" when x"A",
               "1100000" when x"B",
               "1110010" when x"C",
               "1000010" when x"D",
               "0110000" when x"E",
               "0111000" when x"F",
               "1111111" when others;

    o_seg_n(0) <= w_seg_n(6);
    o_seg_n(1) <= w_seg_n(5);
    o_seg_n(2) <= w_seg_n(4);
    o_seg_n(3) <= w_seg_n(3);
    o_seg_n(4) <= w_seg_n(2);
    o_seg_n(5) <= w_seg_n(1);
    o_seg_n(6) <= w_seg_n(0);

end Behavioral;

library ieee;
use ieee.std_logic_1164.all;

library flat_tensors;
use flat_tensors.flat_tensors.all;

entity alu is
    port (
        i_clock   : in std_logic;
        i_reset : in std_logic;

        i_a, i_b: in complex_t;
        i_av, i_bv: in vector_t;

        i_map_code: in std_logic_vector(1 downto 0);
        i_opcode: in std_logic_vector(7 downto 0);

        i_start: in std_logic;
        o_ready: out std_logic;

        o_x: out complex_t;
        o_xv: out vector_t
        
    );
end entity alu;

architecture rtl of alu is



constant COMPLEX_ZERO : complex_t := (others => '0');

constant COMPLEX_ONE : complex_t := (others => '0'); --Fix later too

constant COMPLEX_NEG_ONE : complex_t := (others => '0'); --Fix later

begin


comb_operations : process(i_a, i_b, i_av, i_bv, i_opcode)
begin
case i_map_code is
    when "00" =>
        case i_opcode is
            when x"00" => --Negation
                o_x <= scalar_mul(i_a, COMPLEX_NEG_ONE);
            when x"01" => --Conjugation
                o_x <= scalar_conj(i_a);
            when x"02" => --Sqrt
                null;
            when x"03" => --abs2
                o_x <= scalar_abs2(i_a);
            when x"04" => --abs
                o_x <= scalar_abs(i_a);
            when x"05" => --real
                o_x <= get_re(i_a);
            when x"06" => --img
                o_x <= get_im(i_a);
            when x"07" => --recip
            when x"08" => --add
                o_x <= scalar_add(i_a, i_b);
            when x"09" => --sub
                o_x <= scalar_sub(i_a, i_b);
            when x"0A" => --mul
                o_x <= scalar_mul(i_a, i_b);
            when x"0B" => --div
                o_x <= scalar_div(i_a, i_b);
            when x"0C" => --div
            when x"0D" => --div
            when others =>
                null;
        end case;
    when "01" =>
        case i_opcode is
            when x"00" => --add
                o_xv <= add_vec(i_av, i_bv);
            when x"01" => --sub
                o_xv <= sub_vec(i_av, i_bv);
            when x"02" => --complex add
                o_xv <= vec_plus_complex(i_av, i_b);
            when x"03" => --complex sub
                o_xv <= vec_minus_complex(i_av, i_b)
            when x"04" => --mul
            when x"05" => --mac
            when x"06" => --div
            when x"07" => --conj
            when others =>
                null;
        end case;
    when "10" =>
        case i_opcode is
            when x"01" =>
            when x"02" =>
            when x"03" =>
            when others =>
                null;
        end case;
    when "11" =>
        case i_opcode is
            when x"00" => --

            when x"01" => --
            when x"02" => --
            when x"03" => --
            when x"04" => --
            when others =>
                null;
        end case;
    when others =>
        null;
end case;
end process;


end architecture;
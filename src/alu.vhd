library ieee;
use ieee.std_logic_1164.all;

library tensors;
use tensors.tensors.all;
entity alu is
    port(
        i_a, i_b   : in  complex_t;
        i_av, i_bv : in  vector_t;
        i_map_code : in  std_logic_vector(1 downto 0);
        i_opcode   : in  std_logic_vector(7 downto 0);
        o_x        : out complex_t;
        o_xv       : out vector_t
    );
end entity alu;

architecture rtl of alu is

    constant COMPLEX_ZERO    : complex_t := make_complex(0.0, 0.0);
    constant COMPLEX_ONE     : complex_t := make_complex(1.0, 0.0); --Fix later too
    constant COMPLEX_NEG_ONE : complex_t := make_complex(-1.0, 0.0); --Fix later
    constant SCALAR_TO_SCALAR            : std_logic_vector(1 downto 0) := "00";
    constant VECTOR_TO_VECTOR            : std_logic_vector(1 downto 0) := "01";
    constant VECTOR_TO_SCALAR            : std_logic_vector(1 downto 0) := "10";
    constant VECTOR_AND_SCALAR_TO_VECTOR : std_logic_vector(1 downto 0) := "11";

begin

    comb_operations : process(i_a, i_b, i_av, i_bv, i_opcode, i_map_code)
    begin
        o_x  <= COMPLEX_ZERO;
        o_xv <= VECTOR_ZERO;
        case i_map_code is
            when SCALAR_TO_SCALAR =>
                case i_opcode is
                    when x"00" =>       --Negation
                        o_x <= neg(i_a);
                    when x"01" =>       --Conjugation
                        o_x <= conj(i_a);
                    when x"02" =>       --Sqrt
                        null;
                    when x"03" =>       --abs2
                        o_x <= abs2(i_a);
                    when x"04" =>       --abs
                        -- o_x <= abs(i_a);
                    when x"05" =>       --real
                        o_x.re <= i_a.re;
                        o_x.im <= (others => '0');
                    when x"06" =>       --img
                        o_x.re <= i_a.im;
                        o_x.im <= (others => '0');
                    when x"07" =>       --recip
                        o_x <= make_complex(1.0, 0.0) / i_a;
                    when x"08" =>       --add
                        o_x <= i_a + i_b;
                    when x"09" =>       --sub
                        o_x <= i_a - i_b;
                    when x"0A" =>       --mul
                        o_x <= i_a * i_b;
                    when x"0B" =>       --div
                        o_x <= i_a / i_b;
                    when x"0C" =>       --div
                    when x"0D" =>       --div
                    when others =>
                        null;
                end case;
            when VECTOR_TO_VECTOR =>
                case i_opcode is
                    when x"00" =>
                        o_xv <= vadd(i_av, i_bv);
                    when x"01" =>
                        o_xv <= vsub(i_av, i_bv);
                    when x"02" =>
                        o_xv <= vmul(i_av, i_bv);
                    when x"03" =>
                        o_xv <= vdiv(i_av, i_bv);
                    when x"04" =>
                        for i in 0 to VECTOR_SIZE-1 loop
                            o_xv(i) <= conj(i_av(i));
                        end loop;
                    when x"05" => 
                        
                    when others =>
                        null;
                end case;
            when VECTOR_TO_SCALAR =>
                case i_opcode is
                    when x"01" =>
                    when x"02" =>
                    when x"03" =>
                    when others =>
                        null;
                end case;
            when VECTOR_AND_SCALAR_TO_VECTOR =>
                case i_opcode is
                    when x"01" =>
                    when x"02" =>
                    when x"03" =>
                    when others =>
                        null;
                end case;
            when others =>
                null;
        end case;
    end process;

end architecture;

library ieee;
use ieee.std_logic_1164.all;

library tensors;
use tensors.tensors.all;

library constants;
use constants.constants.all;

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

begin

    comb_operations : process(i_a, i_b, i_av, i_bv, i_opcode, i_map_code)
    begin
        o_x  <= COMPLEX_ZERO;
        o_xv <= VECTOR_ZERO;
        case i_map_code is
            when SCALAR_TO_SCALAR =>
                case i_opcode is
                    when ALU_NEGATION =>
                        o_x <= neg(i_a);
                    when ALU_CONJUGATION =>
                        o_x <= conj(i_a);
                    when ALU_SQRT =>
                        null;
                    when ALU_ABSOLUTE2 =>
                        o_x <= abs2(i_a);
                    when ALU_ABSOLUTE =>
                        o_x <= abs (i_a);
                    when ALU_REAL =>
                        o_x.re <= i_a.re;
                        o_x.im <= (others => '0');
                    when ALU_IMAG =>
                        o_x.re <= i_a.im;
                        o_x.im <= (others => '0');
                    when ALU_RECIP =>
                        o_x <= make_complex(1.0, 0.0) / i_a;
                    when ALU_ADD =>
                        o_x <= i_a + i_b;
                    when ALU_SUB =>
                        o_x <= i_a - i_b;
                    when ALU_MUL =>
                        o_x <= i_a * i_b;
                    when ALU_DIV =>
                        o_x <= i_a / i_b;
                    when others =>
                        null;
                end case;
            when VECTOR_TO_VECTOR =>
                case i_opcode is
                    when ALU_VADD =>
                        o_xv <= vadd(i_av, i_bv);
                    when ALU_VSSUB =>
                        o_xv <= vsub(i_av, i_bv);
                    when ALU_VMUL =>
                        o_xv <= vmul(i_av, i_bv);
                    when ALU_VMAC =>
                        null;           --IMPLEMENT
                    when ALU_VDIV =>
                        o_xv <= vdiv(i_av, i_bv);
                    when ALU_VCONJ =>
                        o_xv <= vlaneconj(i_av);
                    when others =>
                        null;
                end case;
            when VECTOR_TO_SCALAR =>
                case i_opcode is
                    when ALU_DOT =>
                        o_x <= vdot(i_av, i_bv);
                    when ALU_MAX =>
                        o_x <= vmax(i_av);
                    when ALU_SUM =>
                        o_x <= vsum(i_av);
                    when others =>
                        null;
                end case;
            when VECTOR_SCALAR_BROADCAST =>
                case i_opcode is
                    when ALU_VSADD =>
                        o_xv <= vlaneadd(i_av, i_b);
                    when ALU_VSSUB =>
                        o_xv <= vlanesub(i_av, i_b);
                    when ALU_VSMUL =>
                        o_xv <= vlanemul(i_av, i_b);
                    when ALU_VSDIV =>
                        o_xv <= vlanediv(i_av, i_b);
                    when others =>
                        null;
                end case;
            when others =>
                null;
        end case;
    end process;

end architecture;

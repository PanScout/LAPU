library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tensors;
use tensors.tensors.all;

entity matrix_bank_two is
    port(
        i_clock                   : in  std_logic;
        i_reset                   : in  std_logic;
        i_matrix_sel              : in  integer range 0 to 3;
        i_scalar_or_vector_action : in  std_logic;
        i_rw_vector               : in  std_logic;
        i_column_or_row_order     : in  std_logic;
        i_vector_i                : in  integer range 0 to VECTOR_SIZE - 1;
        i_vector_j                : in  integer range 0 to VECTOR_SIZE - 1;
        i_vector                  : in  vector_t;
        o_vector                  : out vector_t;
        i_rw_scalar               : in  std_logic;
        i_scalar_i                : in  integer range 0 to VECTOR_SIZE - 1;
        i_scalar_j                : in  integer range 0 to VECTOR_SIZE - 1;
        i_scalar                  : in  complex_t;
        o_scalar                  : out complex_t
    );
end entity matrix_bank_two;

architecture RTL of matrix_bank_two is

    type   matrix_banks is array (3 downto 0) of matrix_t;
    signal matrices     : matrix_banks;

begin

    sel : process(i_matrix_sel, i_scalar_or_vector_action, i_rw_vector, i_column_or_row_order, i_vector_i, i_vector_j, i_vector, i_rw_scalar, i_scalar_i, i_scalar_j, i_scalar, matrices) is
    begin
        if (i_scalar_or_vector_action = '0') then --Scalar
            if i_rw_scalar = '0' then   --Read
                o_scalar <= matrices(i_matrix_sel)(i_scalar_i)(i_scalar_j);
            else                        --write
                matrices(i_matrix_sel)(i_scalar_i)(i_scalar_j) <= i_scalar;
            end if;
        else                            --Vector
            if i_column_or_row_order = '0' then --Column order

            else                        --Row order

            end if;

        end if;
    end process;

end architecture RTL;

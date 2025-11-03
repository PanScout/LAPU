library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tensors;
use tensors.tensors.all;

entity matrix_bank is
    port(
        i_clock                   : in  std_logic;
        i_reset                   : in  std_logic;
        i_matrix_sel              : in  integer range 0 to 3;
        i_scalar_or_vector_action : in  std_logic;
        i_rw_vector               : in  std_logic;
        i_column_or_row_order     : in  std_logic;
        i_vector_j                : in  integer range 0 to (MATRIX_FACTOR * VECTOR_SIZE) - 1;
        i_vector_i                : in  integer range 0 to (MATRIX_FACTOR * VECTOR_SIZE) - 1;
        i_vector                  : in  vector_t;
        o_vector                  : out vector_t;
        i_rw_scalar               : in  std_logic;
        i_scalar_i                : in  integer range 0 to (VECTOR_SIZE * MATRIX_FACTOR) - 1;
        i_scalar_j                : in  integer range 0 to (VECTOR_SIZE * MATRIX_FACTOR) - 1;
        i_scalar                  : in  complex_t;
        o_scalar                  : out complex_t
    );
end entity matrix_bank;

architecture RTL of matrix_bank is

    -- mat
    type   matrix_banks is array (3 downto 0) of matrix_t;
    signal matrices     : matrix_banks := (others => (others => (others => (others => (others => '0')))));

begin

    sel : process(i_clock, i_reset) is
        variable maj  : integer := 0;
        variable mino : integer := 0;
        variable tmp  : integer := 0;
    begin
        if (rising_edge(i_clock) and i_reset = '0') then

            if (i_scalar_or_vector_action = '0') then
                ----------------------------------------------------------------
                -- Scalar path
                ----------------------------------------------------------------
                if i_rw_scalar = '0' then -- read
                    o_scalar <= matrices(i_matrix_sel)(i_scalar_i, i_scalar_j);
                else                    -- write
                    matrices(i_matrix_sel)(i_scalar_i, i_scalar_j) <= i_scalar;
                end if;

            else
                ----------------------------------------------------------------
                -- Vector path
                -- Convention (matches assembler):
                --   i_vector_i = major_idx  in 0..MATRIX_FACTOR-1 (tile along stepping axis)
                --   i_vector_j = minor_offs in 0..(VECTOR_SIZE*MATRIX_FACTOR-1) (orthogonal coord)
                --
                -- Legacy .cm binaries sometimes encoded:
                --   i_vector_i = minor_offs,  i_vector_j = major_idx
                -- We detect that pattern in .cm and swap to be robust.
                ----------------------------------------------------------------
                maj  := i_vector_i;
                mino := i_vector_j;

                if i_column_or_row_order = '1' then -- Column-major: X fixed = mino, Y steps with maj

                    -- Legacy-encoding shim: if maj looks like minor_offs (>= MATRIX_FACTOR)
                    -- and mino looks like a tile (< MATRIX_FACTOR), swap them.
                    if (maj >= MATRIX_FACTOR) and (mino < MATRIX_FACTOR) then
                        tmp  := maj;
                        maj  := mino;   -- now proper tile
                        mino := tmp;    -- now minor_offs
                    end if;

                    -- Range sanity (helps catch bad encodings early)
                    assert (maj >= 0) and (maj < MATRIX_FACTOR)
                    report "matrix_bank: column-major 'maj' (tile) out of range" severity failure;
                    assert (mino >= 0) and (mino < VECTOR_SIZE * MATRIX_FACTOR)
                    report "matrix_bank: column-major 'mino' (minor_offs) out of range" severity failure;

                    if i_rw_vector = '0' then -- read column -> o_vector
                        for k in 0 to VECTOR_SIZE - 1 loop
                            o_vector(k) <= matrices(i_matrix_sel)(
                                mino,   -- X fixed (column)
                                maj * VECTOR_SIZE + k -- Y stepping
                            );
                        end loop;
                    else                -- write column <- i_vector
                        for k in 0 to VECTOR_SIZE - 1 loop
                            matrices(i_matrix_sel)(
                                mino,   -- X fixed (column)
                                maj * VECTOR_SIZE + k -- Y stepping
                            ) <= i_vector(k);
                        end loop;
                    end if;

                else                    -- Row-major: Y fixed = mino, X steps with maj

                    assert (maj >= 0) and (maj < MATRIX_FACTOR)
                    report "matrix_bank: row-major 'maj' (tile) out of range" severity failure;
                    assert (mino >= 0) and (mino < VECTOR_SIZE * MATRIX_FACTOR)
                    report "matrix_bank: row-major 'mino' (minor_offs) out of range" severity failure;

                    if i_rw_vector = '0' then -- read row -> o_vector
                        for k in 0 to VECTOR_SIZE - 1 loop
                            o_vector(k) <= matrices(i_matrix_sel)(
                                maj * VECTOR_SIZE + k, -- X stepping
                                mino    -- Y fixed (row)
                            );
                        end loop;
                    else                -- write row <- i_vector
                        for k in 0 to VECTOR_SIZE - 1 loop
                            matrices(i_matrix_sel)(
                                maj * VECTOR_SIZE + k, -- X stepping
                                mino    -- Y fixed (row)
                            ) <= i_vector(k);
                        end loop;
                    end if;

                end if;                 -- rc

            end if;                     -- scalar/vector

        elsif (i_reset = '1') then
            null;
        end if;
    end process;

end architecture RTL;

-- tb_matrix_bank.vhd
-- VHDL-2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- If your package was compiled into library "flat_tensors", keep these:
library flat_tensors;
use flat_tensors.flat_tensors.all;
-- If instead it is in "work", comment the two lines above and:
-- use work.flat_tensors.all;

library std;
use std.env.all;  -- for finish

entity tb_matrix_bank is
end entity;

architecture sim of tb_matrix_bank is
  constant CLK_PERIOD : time := 10 ns;

  -- Clock/Reset
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  -- DUT I/O
  signal i_matrix_sel              : integer range 0 to 3 := 0;
  signal i_scalar_or_vector_action : std_logic := '0';   -- '0' scalar, '1' vector

  -- Vector path
  signal i_rw_vector           : std_logic := '0';       -- '0' read, '1' write
  signal i_column_or_row_order : std_logic := '0';       -- '0' row-major, '1' col-major
  signal i_vector_i            : integer range 0 to MATRIX_SUBVECTORS - 1 := 0;
  signal i_vector_j            : integer range 0 to MATRIX_SUBVECTORS - 1 := 0;
  signal i_vector              : vector_t := (others => '0');
  signal o_vector              : vector_t;

  -- Scalar path
  signal i_rw_scalar  : std_logic := '0';                -- '0' read, '1' write
  signal i_scalar_i   : integer range 0 to WORDS_PER_AXIS - 1 := 0;
  signal i_scalar_j   : integer range 0 to WORDS_PER_AXIS - 1 := 0;
  signal i_scalar     : complex_t := (others => '0');
  signal o_scalar     : complex_t;

  -- Handy bounds derived from the package
  constant BMAX : integer := MATRIX_SUBVECTORS - 1;  -- max subvector index
  constant WMAX : integer := WORDS_PER_AXIS - 1;     -- max element index

  -- Small helpers -------------------------------------------------------------

  -- min(a,b) for integers
  function imin(a, b : integer) return integer is
  begin
    if a < b then return a; else return b; end if;
  end function;

  -- Build a complex_t from integer real/imag parts (two's-complement)
  function cplx(re_i, im_i : integer) return complex_t is
    constant re_s : std_logic_vector(PART_WIDTH-1 downto 0)
      := std_logic_vector(to_signed(re_i, PART_WIDTH));
    constant im_s : std_logic_vector(PART_WIDTH-1 downto 0)
      := std_logic_vector(to_signed(im_i, PART_WIDTH));
  begin
    return make_complex(re_s, im_s);
  end function;

  -- Deterministic test vector: lane n = (re=n, im=-n)
  function build_test_vector return vector_t is
    variable v : vector_t := (others => '0');
  begin
    for n in 0 to VECTOR_WORD_WIDTH-1 loop
      v := set_vec_num(v, n, cplx(n, -n));
    end loop;
    return v;
  end function;

begin
  -- Clock generator
  clk <= not clk after CLK_PERIOD/2;

  -- DUT instance
  uut: entity work.matrix_bank
    port map (
      i_clock                  => clk,
      i_reset                  => rst,
      i_matrix_sel             => i_matrix_sel,
      i_scalar_or_vector_action=> i_scalar_or_vector_action,

      i_rw_vector              => i_rw_vector,
      i_column_or_row_order    => i_column_or_row_order,
      i_vector_i               => i_vector_i,
      i_vector_j               => i_vector_j,
      i_vector                 => i_vector,
      o_vector                 => o_vector,

      i_rw_scalar              => i_rw_scalar,
      i_scalar_i               => i_scalar_i,
      i_scalar_j               => i_scalar_j,
      i_scalar                 => i_scalar,
      o_scalar                 => o_scalar
    );

  -- Stimulus ---------------------------------------------------------------
  stim : process
    constant VEC : vector_t := build_test_vector;
    constant S_I : integer := imin(3, WMAX);      -- safe scalar row index
    constant S_J : integer := imin(1, WMAX);      -- safe scalar col index
    constant BI0 : integer := imin(1, BMAX);      -- safe block row (row-major test)
    constant BJ0 : integer := imin(1, BMAX);      -- safe block col (row-major test)
    constant BI1 : integer := 0;                  -- safe block row (col-major test)
    constant BJ1 : integer := imin(1, BMAX);      -- safe block col (col-major test)
    variable exp_scalar : complex_t;
  begin
    ------------------------------------------------------------------------
    -- Reset sequence
    ------------------------------------------------------------------------
    rst <= '1';
    wait for 3*CLK_PERIOD;
    rst <= '0';
    wait for CLK_PERIOD;

    ------------------------------------------------------------------------
    -- SCALAR path: write then read back on bank 0
    ------------------------------------------------------------------------
    i_matrix_sel              <= 0;
    i_scalar_or_vector_action <= '0';     -- use scalar path

    i_scalar_i <= S_I;
    i_scalar_j <= S_J;
    i_scalar   <= cplx(123, -45);
    exp_scalar := cplx(123, -45);

    -- write
    i_rw_scalar <= '1';
    wait until rising_edge(clk);

    -- read
    i_rw_scalar <= '0';
    wait until rising_edge(clk);
    wait for 1 ns; -- settle
    assert o_scalar = exp_scalar
      report "SCALAR mismatch @ (" & integer'image(S_I) & "," & integer'image(S_J) & ")"
      severity error;

    ------------------------------------------------------------------------
    -- VECTOR path (row-major): write/read subvector on bank 0
    ------------------------------------------------------------------------
    i_scalar_or_vector_action <= '1';     -- use vector path
    i_column_or_row_order     <= '0';     -- row-major
    i_vector_i                <= BI0;     -- safe block row
    i_vector_j                <= BJ0;     -- safe block col
    i_vector                  <= VEC;

    -- write
    i_rw_vector <= '1';
    wait until rising_edge(clk);

    -- read
    i_rw_vector <= '0';
    wait until rising_edge(clk);
    wait for 1 ns;
    assert o_vector = VEC
      report "VECTOR (row-major) mismatch @ block("
             & integer'image(BI0) & "," & integer'image(BJ0) & ")"
      severity error;

    ------------------------------------------------------------------------
    -- VECTOR path (column-major): write/read subvector on bank 1
    ------------------------------------------------------------------------
    i_matrix_sel              <= 1;
    i_column_or_row_order     <= '1';     -- column-major
    i_vector_i                <= BI1;
    i_vector_j                <= BJ1;
    -- reuse VEC

    -- write
    i_rw_vector <= '1';
    wait until rising_edge(clk);

    -- read
    i_rw_vector <= '0';
    wait until rising_edge(clk);
    wait for 1 ns;
    assert o_vector = VEC
      report "VECTOR (column-major) mismatch @ block("
             & integer'image(BI1) & "," & integer'image(BJ1) & ")"
      severity error;

    ------------------------------------------------------------------------
    -- Done
    ------------------------------------------------------------------------
    report "tb_matrix_bank: PASS" severity note;
    finish;
  end process;

end architecture;

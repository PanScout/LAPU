-- linear_flat_pkg.vhd
-- Library: flat_linear
-- Package: linear_flat (spec)
--
-- Flattened types for fixed-point (Q31.32) and complex numbers, plus
-- helpers for vectors/matrices carried as std_logic_vector buses.
--
-- Interfaces avoid records/arrays so GHDL + Surfer handle them cleanly.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package linear_flat is
  ------------------------------------------------------------------------------
  -- Fixed-point configuration
  ------------------------------------------------------------------------------
  constant FX_W    : natural := 64;   -- fixed64 width
  constant FX_FRAC : natural := 32;   -- Q31.32 fractional bits
  constant CMP_W   : natural := 128;  -- complex128 width (re|im packed)

  subtype fx64_s is signed(FX_W-1 downto 0);

  ------------------------------------------------------------------------------
  -- Fixed-point conversion & arithmetic (Q31.32)
  ------------------------------------------------------------------------------
  -- Converts between SLV(63:0) and fx64_s
  function fx_from_slv(x : std_logic_vector(FX_W-1 downto 0)) return fx64_s;
  function slv_from_fx(x : fx64_s) return std_logic_vector;

  -- Basic ops (wrap add/sub). Use fx_sat explicitly if you need saturation.
  function fx_add(a,b : fx64_s) return fx64_s;
  function fx_sub(a,b : fx64_s) return fx64_s;

  -- Saturate an arbitrary-width signed to 64-bit Q31.32
  function fx_sat(x : signed) return fx64_s;

  -- 64x64 -> 128 multiply, round-to-nearest, arithmetic shift right by FX_FRAC, then saturate
  function fx_mul(a,b : fx64_s) return fx64_s;


  -- Complex packing: [re(63:0) | im(63:0)] => CMP_W bits
  function pack_complex(re_i, im_i : fx64_s) return std_logic_vector;  -- CMP_W bits
  function unpack_re(c : std_logic_vector) return fx64_s;  -- accept any slice range
  function unpack_im(c : std_logic_vector) return fx64_s;  -- accept any slice range

  ------------------------------------------------------------------------------
  -- Flat vector/matrix helpers (element width = CMP_W)
  -- Vector length N: bus = N * CMP_W bits
  -- Matrix N x N   : bus = N * N * CMP_W bits (row-major)
  ------------------------------------------------------------------------------
  function vec_bits(N : natural) return natural;
  function mat_bits(N : natural) return natural;

  function vec_get(vec : std_logic_vector; N, idx : natural) return std_logic_vector; -- CMP_W slice
  function vec_set(vec : std_logic_vector; N, idx : natural; val : std_logic_vector)
    return std_logic_vector;

  function mat_idx(N,row,col : natural) return natural; -- row-major index
  function mat_get(mat : std_logic_vector; N, row, col : natural) return std_logic_vector; -- CMP_W slice
  function mat_set(mat : std_logic_vector; N, row, col : natural; val : std_logic_vector)
    return std_logic_vector;

end package linear_flat;

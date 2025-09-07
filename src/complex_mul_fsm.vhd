-- src/complex_mul_fsm.vhd
-- 3-cycle complex multiply using Gauss's trick (3 real multiplies).
-- Handshake:
--   - Drive i_start='1' for one clk when o_ready='1' with i_a/i_b stable.
--   - Result appears with o_valid='1' for one clk exactly 3 cycles later.
-- Notes:
--   - No pipelining: cycles are split to keep the combinational depth modest.
--   - Uses only add_parts/sub_parts from flat_tensors; local fixed-point mul implemented here.
--   - Blind truncation (no rounding/saturation).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library flat_tensors;
use flat_tensors.flat_tensors.all;

entity complex_mul_fsm is
  port (
    i_clk   : in  std_logic;        -- clock
    i_rst   : in  std_logic;        -- synchronous, active-high reset
    i_start : in  std_logic;        -- pulse when o_ready='1' and inputs stable
    i_a     : in  complex_t;        -- operand A (packed [REAL|IMAG])
    i_b     : in  complex_t;        -- operand B (packed [REAL|IMAG])
    o_ready : out std_logic;        -- '1' => can accept a new start
    o_valid : out std_logic;        -- pulses '1' for one cycle when o_y valid
    o_y     : out complex_t         -- result (packed [REAL|IMAG])
  );
end entity complex_mul_fsm;

architecture rtl of complex_mul_fsm is
  -----------------------------------------------------------------------------
  -- Local fixed-point multiply with truncation (Q(INT.FRAC), FRAC=PART_FRAC_BITS)
  -- Computes: (a * b) >> PART_FRAC_BITS, then truncates to PART_WIDTH.
  -----------------------------------------------------------------------------
  function fx_mul_trunc_q(a, b : std_logic_vector) return std_logic_vector is
    variable sa         : signed(PART_WIDTH-1 downto 0);
    variable sb         : signed(PART_WIDTH-1 downto 0);
    variable prod_full  : signed((2*PART_WIDTH)-1 downto 0);
    variable prod_shift : signed((2*PART_WIDTH)-1 downto 0);
  begin
    sa := signed(a);
    sb := signed(b);
    prod_full  := sa * sb;                                 -- W×W → 2W
    prod_shift := shift_right(prod_full, PART_FRAC_BITS);  -- realign Q-scale
    return std_logic_vector(resize(prod_shift, PART_WIDTH));  -- truncate
  end function;

  -----------------------------------------------------------------------------
  -- FSM state
  -----------------------------------------------------------------------------
  type state_t is (S_IDLE, S_PARTIALS, S_FINAL, S_OUT);
  signal r_state, r_state_next : state_t := S_IDLE;

  -----------------------------------------------------------------------------
  -- Latched inputs (stable across the operation)
  -----------------------------------------------------------------------------
  signal r_a_re, r_a_im : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
  signal r_b_re, r_b_im : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');

  -----------------------------------------------------------------------------
  -- Cycle 1 partials (concurrent within the cycle):
  --   s1 = a_r + a_i
  --   s2 = b_r + b_i
  --   p1 = a_r * b_r
  --   p2 = a_i * b_i
  -----------------------------------------------------------------------------
  signal r_s1_ar_plus_ai : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
  signal r_s2_br_plus_bi : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
  signal r_p1_ar_times_br: std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
  signal r_p2_ai_times_bi: std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');

  -----------------------------------------------------------------------------
  -- Cycle 2 results and p3:
  --   p3 = (a_r + a_i) * (b_r + b_i)   (Gauss)
  --   real = p1 - p2
  --   imag = (p3 - p1) - p2
  -----------------------------------------------------------------------------
  signal r_p3_sumA_sumB  : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0'); -- for waves
  signal r_real_out_bits : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');
  signal r_imag_out_bits : std_logic_vector(PART_WIDTH-1 downto 0) := (others => '0');

  -----------------------------------------------------------------------------
  -- Outputs / handshakes
  -----------------------------------------------------------------------------
  signal r_o_y     : complex_t := (others => '0');
  signal r_o_valid : std_logic := '0';
  signal r_o_ready : std_logic := '1';
begin
  -----------------------------------------------------------------------------
  -- Next-state logic
  -----------------------------------------------------------------------------
  process(r_state, i_start, r_o_ready)
  begin
    r_state_next <= r_state;
    case r_state is
      when S_IDLE =>
        if (i_start = '1') and (r_o_ready = '1') then
          r_state_next <= S_PARTIALS;
        end if;

      when S_PARTIALS =>
        r_state_next <= S_FINAL;

      when S_FINAL =>
        r_state_next <= S_OUT;

      when S_OUT =>
        r_state_next <= S_IDLE;
    end case;
  end process;

  -----------------------------------------------------------------------------
  -- Sequential logic
  -----------------------------------------------------------------------------
  process(i_clk)
    -- Local temp for fresh p3 so imag uses the *new* value (avoid old-signal readback)
    variable v_p3_sumA_sumB : std_logic_vector(PART_WIDTH-1 downto 0);
  begin
    if rising_edge(i_clk) then
      -- default strobes
      r_o_valid <= '0';

      if (i_rst = '1') then
        r_state   <= S_IDLE;
        r_o_ready <= '1';
        r_o_valid <= '0';
        r_o_y     <= (others => '0');

        r_a_re <= (others => '0'); r_a_im <= (others => '0');
        r_b_re <= (others => '0'); r_b_im <= (others => '0');

        r_s1_ar_plus_ai <= (others => '0');
        r_s2_br_plus_bi <= (others => '0');
        r_p1_ar_times_br <= (others => '0');
        r_p2_ai_times_bi <= (others => '0');

        r_p3_sumA_sumB  <= (others => '0');
        r_real_out_bits <= (others => '0');
        r_imag_out_bits <= (others => '0');

      else
        r_state <= r_state_next;

        case r_state is
          when S_IDLE =>
            -- Ready for new work
            r_o_ready <= '1';

            if (i_start = '1') and (r_o_ready = '1') then
              -- Latch operands (unpack once)
              r_a_re <= get_re(i_a);
              r_a_im <= get_im(i_a);
              r_b_re <= get_re(i_b);
              r_b_im <= get_im(i_b);
              -- Busy during operation
              r_o_ready <= '0';
            end if;

          when S_PARTIALS =>
            -- Cycle 1: independent partials computed concurrently
            r_s1_ar_plus_ai <= add_parts(r_a_re, r_a_im);  -- s1 = a_r + a_i
            r_s2_br_plus_bi <= add_parts(r_b_re, r_b_im);  -- s2 = b_r + b_i
            r_p1_ar_times_br <= fx_mul_trunc_q(r_a_re, r_b_re); -- p1 = ar*br
            r_p2_ai_times_bi <= fx_mul_trunc_q(r_a_im, r_b_im); -- p2 = ai*bi

          when S_FINAL =>
            -- Cycle 2: compute p3 as a variable (fresh this cycle), then form outputs
            v_p3_sumA_sumB := fx_mul_trunc_q(r_s1_ar_plus_ai, r_s2_br_plus_bi); -- p3=(ar+ai)*(br+bi)

            -- real = p1 - p2
            r_real_out_bits <= sub_parts(r_p1_ar_times_br, r_p2_ai_times_bi);

            -- imag = (p3 - p1) - p2  (use the fresh v_p3_sumA_sumB)
            r_imag_out_bits <= sub_parts(
                                  sub_parts(v_p3_sumA_sumB, r_p1_ar_times_br),
                                  r_p2_ai_times_bi);

            -- For waveform visibility (updates next edge)
            r_p3_sumA_sumB <= v_p3_sumA_sumB;

          when S_OUT =>
            -- Cycle 3: pack outputs, pulse valid, and return to ready
            r_o_y     <= make_complex(r_real_out_bits, r_imag_out_bits);
            r_o_valid <= '1';
            r_o_ready <= '1';

          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  o_ready <= r_o_ready;
  o_valid <= r_o_valid;
  o_y     <= r_o_y;

end architecture rtl;

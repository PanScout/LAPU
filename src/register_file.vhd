library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tensors;
use tensors.tensors.all;

entity register_file is
  port(
    i_clock                                : in  std_logic;
    i_reset                                : in  std_logic;
    i_scalar_reg_sel_1, i_scalar_reg_sel_2 : in  integer range 0 to 7;
    o_scalar_reg_1, o_scalar_reg_2         : out complex_t;
    i_scalar_reg_input                     : in  complex_t;
    i_scalar_write_sel                     : in  integer range 0 to 7;
    i_scalar_write_enable                  : in  std_logic;
    i_vector_reg_sel_1, i_vector_reg_sel_2 : in  integer range 0 to 7;
    o_vector_reg_1, o_vector_reg_2         : out vector_t;
    i_vector_reg_input                     : in  vector_t;
    i_vector_write_sel                     : in  integer range 0 to 7;
    i_vector_write_enable                  : in  std_logic
  );
end register_file;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tensors;
use tensors.tensors.all;

architecture arch of register_file is
  constant REGISTER_FILE_LENGTH : integer := 8;

  -- Storage
  type scalar_regs_t is array (0 to REGISTER_FILE_LENGTH - 1) of complex_t;
  signal scalar_regs : scalar_regs_t := (others => (others => (others => '0')));

  type vector_regs_t is array (0 to REGISTER_FILE_LENGTH - 1) of vector_t;
  signal vector_regs : vector_regs_t := ((others => (others => (others => (others => '0')))));
begin
  ---------------------------------------------------------------------------
  -- Synchronous write + synchronous reset
  ---------------------------------------------------------------------------
  process(i_clock)
  begin
    if rising_edge(i_clock) then
      if i_reset = '1' then
        for i in 0 to REGISTER_FILE_LENGTH - 1 loop
          scalar_regs(i) <= COMPLEX_ZERO;
          vector_regs(i) <= VECTOR_ZERO;
        end loop;
      else
        -- Scalar write (block writes to x0)
        if i_scalar_write_enable = '1' then
          if i_scalar_write_sel /= 0 then
            scalar_regs(i_scalar_write_sel) <= i_scalar_reg_input;
          end if;
        end if;

        -- Vector write (block writes to x0)
        if i_vector_write_enable = '1' then
          if i_vector_write_sel /= 0 then
            vector_regs(i_vector_write_sel) <= i_vector_reg_input;
          end if;
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Asynchronous reads (combinational muxes)
  -- x0 is hardwired to zero via the conditional
  ---------------------------------------------------------------------------
  o_scalar_reg_1 <= COMPLEX_ZERO when i_scalar_reg_sel_1 = 0
                    else scalar_regs(i_scalar_reg_sel_1);

  o_scalar_reg_2 <= COMPLEX_ZERO when i_scalar_reg_sel_2 = 0
                    else scalar_regs(i_scalar_reg_sel_2);

  o_vector_reg_1 <= VECTOR_ZERO when i_vector_reg_sel_1 = 0
                    else vector_regs(i_vector_reg_sel_1);

  o_vector_reg_2 <= VECTOR_ZERO when i_vector_reg_sel_2 = 0
                    else vector_regs(i_vector_reg_sel_2);
end architecture;

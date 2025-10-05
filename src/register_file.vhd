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

architecture arch of register_file is

  constant READ                 : std_logic := '0';
  constant WRITE                : std_logic := '1';
  constant REGISTER_FILE_LENGTH : integer   := 8;

  type   scalar_regs_t is array (0 to REGISTER_FILE_LENGTH - 1) of complex_t;
  signal scalar_regs   : scalar_regs_t;

  type   vector_regs_t is array (0 to REGISTER_FILE_LENGTH - 1) of vector_t;
  signal vector_regs   : vector_regs_t;

begin
  --First register is always hardwired to 0
  scalar_regs(0) <= COMPLEX_ZERO;
  vector_regs(0) <= VECTOR_ZERO;

  scalars : process(i_clock) is
  begin
    if (rising_edge(i_clock) and i_reset = '0') then
      if (i_scalar_write_enable = READ) then
        o_scalar_reg_1 <= scalar_regs(i_scalar_reg_sel_1);
        o_scalar_reg_2 <= scalar_regs(i_scalar_reg_sel_2);
      elsif (i_scalar_write_enable = WRITE) then
        scalar_regs(i_scalar_write_sel) <= i_scalar_reg_input;
      end if;
    elsif(rising_edge(i_clock) and i_reset = '1') then
      for i in 0 to REGISTER_FILE_LENGTH loop
       scalar_regs(i) <= COMPLEX_ZERO; 
      end loop;
    end if;

  end process scalars;

  vectors : process(i_clock) is
  begin
    if (rising_edge(i_clock)) then
      if (i_vector_write_enable = READ) then
        o_vector_reg_1 <= vector_regs(i_vector_reg_sel_1);
        o_vector_reg_2 <= vector_regs(i_vector_reg_sel_2);
      elsif (i_vector_write_enable = WRITE) then
        vector_regs(i_vector_write_sel) <= i_vector_reg_input;
      end if;
    elsif(rising_edge(i_clock) and i_reset = '1') then
      for i in 0 to REGISTER_FILE_LENGTH loop
       vector_regs(i) <= VECTOR_ZERO; 
      end loop;
    end if;
  end process vectors;

end architecture;

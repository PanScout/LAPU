library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library flat_tensors;
use flat_tensors.flat_tensors.all;

entity register_file is
  port (
    i_clock : in  std_logic;
    i_reset : in std_logic;
    
    i_scalar_reg_sel_1, i_scalar_reg_sel_2: in integer range 0 to 7;
    o_scalar_reg_1, o_scalar_reg_2: out complex_t;
    i_scalar_reg_input: in complex_t;
    i_scalar_write_sel: in integer range 0 to 7;
    i_scalar_write_enable: in std_logic;
    
    i_vector_reg_sel_1, i_vector_reg_sel_2: in integer range 0 to 7;
    o_vector_reg_1, o_vector_reg_2: out vector_t;
    i_vector_reg_input: in vector_t;
    i_vector_write_sel: in integer range 0 to 7;
    i_vector_write_enable: in std_logic

  ) ;
end register_file ;

architecture arch of register_file is


signal scalar_reg_0, scalar_reg_1, scalar_reg_2, scalar_reg_3,scalar_reg_4, scalar_reg_5,scalar_reg_6,scalar_reg_7: complex_t;
signal vector_reg_0, vector_reg_1, vector_reg_2, vector_reg_3, vector_reg_4, vector_reg_5,vector_reg_6,vector_reg_7: vector_t;

constant COMPLEX_ZERO: complex_t := (others => '0');
constant VECTOR_ZERO: vector_t := (others => '0');

begin

  with i_scalar_reg_sel_1 select o_scalar_reg_1 <=
    COMPLEX_ZERO when 0,
    scalar_reg_1 when 1,
    scalar_reg_2 when 2,
    scalar_reg_3 when 3,
    scalar_reg_4 when 4,
    scalar_reg_5 when 5,
    scalar_reg_6 when 6,
    scalar_reg_7 when 7,
    COMPLEX_ZERO when others;

  with i_scalar_reg_sel_2 select o_scalar_reg_2 <=
    COMPLEX_ZERO when 0,
    scalar_reg_1 when 1,
    scalar_reg_2 when 2,
    scalar_reg_3 when 3,
    scalar_reg_4 when 4,
    scalar_reg_5 when 5,
    scalar_reg_6 when 6,
    scalar_reg_7 when 7,
    COMPLEX_ZERO when others;

  with i_vector_reg_sel_1 select o_vector_reg_1 <=
    VECTOR_ZERO when 0,
    vector_reg_1 when 1,
    vector_reg_2 when 2,
    vector_reg_3 when 3,
    vector_reg_4 when 4,
    vector_reg_5 when 5,
    vector_reg_6 when 6,
    vector_reg_7 when 7,
    VECTOR_ZERO when others;

  with i_vector_reg_sel_2 select o_vector_reg_2 <=
    VECTOR_ZERO when 0,
    vector_reg_1 when 1,
    vector_reg_2 when 2,
    vector_reg_3 when 3,
    vector_reg_4 when 4,
    vector_reg_5 when 5,
    vector_reg_6 when 6,
    vector_reg_7 when 7,
    VECTOR_ZERO when others;



scalar : process(i_clock)
begin
    if rising_edge(i_clock) then
        if i_reset = '0' and i_scalar_write_enable = '1' then
             case i_scalar_write_sel is
                when 0 => 
                  scalar_reg_0 <= COMPLEX_ZERO;
                when 1 =>
                  scalar_reg_1 <= i_scalar_reg_input;
                when 2 =>
                  scalar_reg_2 <= i_scalar_reg_input;
                when 3 =>
                  scalar_reg_3 <= i_scalar_reg_input;
                when 4 =>
                  scalar_reg_4 <= i_scalar_reg_input;
                when 5 =>
                  scalar_reg_5 <= i_scalar_reg_input;
                when 6 =>
                  scalar_reg_6 <= i_scalar_reg_input;
                when 7 =>
                  scalar_reg_7 <= i_scalar_reg_input;
                when others =>
                    null;
            end case;
        else
          scalar_reg_0 <= COMPLEX_ZERO;
          scalar_reg_1 <= COMPLEX_ZERO;
          scalar_reg_2 <= COMPLEX_ZERO;
          scalar_reg_3 <= COMPLEX_ZERO;
          scalar_reg_4 <= COMPLEX_ZERO;
          scalar_reg_5 <= COMPLEX_ZERO;
          scalar_reg_6 <= COMPLEX_ZERO;
          scalar_reg_7 <= COMPLEX_ZERO;
        end if;
    end if;
end process;


vector : process(i_clock)
begin
    if rising_edge(i_clock) then
        if i_reset = '0' and i_vector_write_enable = '1' then
             case i_vector_write_sel is
                when 0 => 
                  vector_reg_0 <= VECTOR_ZERO;
                when 1 =>
                  vector_reg_1 <= i_vector_reg_input;
                when 2 =>
                  vector_reg_2 <= i_vector_reg_input;
                when 3 =>
                  vector_reg_3 <= i_vector_reg_input;
                when 4 =>
                  vector_reg_4 <= i_vector_reg_input;
                when 5 =>
                  vector_reg_5 <= i_vector_reg_input;
                when 6 =>
                  vector_reg_6 <= i_vector_reg_input;
                when 7 =>
                  vector_reg_7 <= i_vector_reg_input;
                when others =>
                    null;
            end case;
        else
          vector_reg_0 <= VECTOR_ZERO;
          vector_reg_1 <= VECTOR_ZERO;
          vector_reg_2 <= VECTOR_ZERO;
          vector_reg_3 <= VECTOR_ZERO;
          vector_reg_4 <= VECTOR_ZERO;
          vector_reg_5 <= VECTOR_ZERO;
          vector_reg_6 <= VECTOR_ZERO;
          vector_reg_7 <= VECTOR_ZERO;
        end if;
    end if;
end process;



end architecture ; -- arch
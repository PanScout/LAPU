library ieee;
use ieee.std_logic_1164.all;

library flat_tensors;
use flat_tensors.flat_tensors.all;

entity matrix_bank is
  port (
    
    i_clock: in std_logic;
    i_reset: in std_logic;
    i_matrix_sel: in integer range 0 to 3;
    i_scalar_or_vector_action: in std_logic;

    i_rw_vector: in std_logic;
    i_column_or_row_order: in std_logic;
    i_vector_i: in integer range 0 to MATRIX_SUBVECTORS - 1;
    i_vector_j: in integer range 0 to MATRIX_SUBVECTORS - 1;
    i_vector: in vector_t;
    o_vector: out vector_t;
    
    
    i_rw_scalar: in std_logic;
    i_scalar_i: in integer range 0 to WORDS_PER_AXIS - 1;
    i_scalar_j: in integer range 0 to WORDS_PER_AXIS - 1;
    i_scalar: in complex_t;
    o_scalar: out complex_t

  ) ;
end matrix_bank ;

architecture arch of matrix_bank is



signal matrix_0, matrix_1, matrix_2, matrix_3: matrix_t := (others => '0');

function write_vector( m : matrix_t; i, j : integer range 0 to MATRIX_SUBVECTORS-1; column_or_row_order : std_logic; v : vector_t ) return matrix_t is
  variable rmat         : matrix_t := m;
  variable row_index    : natural range 0 to WORDS_PER_AXIS-1;
  variable column_index : natural range 0 to WORDS_PER_AXIS-1;
begin
  if column_or_row_order = '0' then  -- Row Major order
    row_index    := i*VECTOR_WORD_WIDTH;
    column_index := j;
    for n in 0 to VECTOR_WORD_WIDTH - 1 loop
      rmat  := set_mat_num(rmat, row_index, column_index, get_vec_num(v, n));
      row_index := row_index + 1;
    end loop;
  else                                -- Column Major order
    row_index    := i;
    column_index := j*VECTOR_WORD_WIDTH;
    for n in 0 to VECTOR_WORD_WIDTH - 1 loop
      rmat  := set_mat_num(rmat, row_index, column_index, get_vec_num(v, n));
      column_index := column_index + 1;
    end loop;
  end if;

  return rmat;
end function;


function read_vector(m: matrix_t; i,j: integer range 0 to MATRIX_SUBVECTORS-1; column_or_row_order: std_logic) return vector_t is
    variable rvec: vector_t := (others => '0');
    variable row_index: natural  range 0 to WORDS_PER_AXIS-1;
    variable column_index: natural  range 0 to WORDS_PER_AXIS-1;
begin
    if column_or_row_order = '0' then --Row Major order
        row_index := i*VECTOR_WORD_WIDTH;
        column_index := j;
        for n in 0 to VECTOR_WORD_WIDTH - 1 loop
            rvec := set_vec_num(rvec, n, get_mat_num(m, row_index, column_index)  );
            row_index := row_index + 1;
        end loop;
    else
        row_index := i;
        column_index := j * VECTOR_WORD_WIDTH;
        for n in 0 to VECTOR_WORD_WIDTH - 1 loop
            rvec := set_vec_num(rvec, n, get_mat_num(m, row_index, column_index)  );
            column_index := column_index + 1;
        end loop;
    end if;

    return rvec;

end function;





begin


io : process(i_clock, i_reset)
begin
    if rising_edge(i_clock) then
        if i_reset = '0' then
            if i_scalar_or_vector_action = '0' then
                case i_matrix_sel is
                    when 0 =>
                        if i_rw_scalar = '0' then
                            o_scalar <= get_mat_num(matrix_0, i_scalar_i, i_scalar_j);
                        else
                            matrix_0 <= set_mat_num(matrix_0, i_scalar_i, i_scalar_j, i_scalar);
                        end if;
                    when 1 =>
                        if i_rw_scalar = '0' then
                            o_scalar <= get_mat_num(matrix_1, i_scalar_i, i_scalar_j);
                        else
                            matrix_1 <= set_mat_num(matrix_1, i_scalar_i, i_scalar_j, i_scalar);
                        end if;
                    when 2 =>
                        if i_rw_scalar = '0' then
                            o_scalar <= get_mat_num(matrix_2, i_scalar_i, i_scalar_j);
                        else
                            matrix_2 <= set_mat_num(matrix_2, i_scalar_i, i_scalar_j, i_scalar);
                        end if;
                    when 3 => 
                        if i_rw_scalar = '0' then
                            o_scalar <= get_mat_num(matrix_3, i_scalar_i, i_scalar_j);
                        else
                            matrix_3 <= set_mat_num(matrix_3, i_scalar_i, i_scalar_j, i_scalar);
                        end if;
                end case;  
            else 
                case i_matrix_sel is
                        when 0 =>
                            if i_rw_vector= '0' then
                                o_vector <= read_vector(matrix_0, i_vector_i, i_vector_j, i_column_or_row_order);
                            else
                                matrix_0 <= write_vector(matrix_0, i_vector_i, i_vector_j, i_column_or_row_order, i_vector);
                            end if;
                        when 1 =>
                            if i_rw_vector = '0' then
                                o_vector <= read_vector(matrix_1, i_vector_i, i_vector_j, i_column_or_row_order);
                            else
                                matrix_1 <= write_vector(matrix_1, i_vector_i, i_vector_j, i_column_or_row_order, i_vector);
                            end if;
                        when 2 =>
                            if i_rw_vector = '0' then
                                o_vector <= read_vector(matrix_2, i_vector_i, i_vector_j, i_column_or_row_order);
                            else
                                matrix_2 <= write_vector(matrix_2, i_vector_i, i_vector_j, i_column_or_row_order, i_vector);
                            end if;
                        when 3 => 
                            if i_rw_vector = '0' then
                                o_vector <= read_vector(matrix_3, i_vector_i, i_vector_j, i_column_or_row_order);
                            else
                                matrix_3 <= write_vector(matrix_3, i_vector_i, i_vector_j, i_column_or_row_order, i_vector);
                            end if;
                    end case;   
             end if ;   
        end if ;
    end if;
end process;


--Later on I will make this set each subvector of each bank to 0 one a time.
reset : process(i_clock, i_reset)
begin
    if rising_edge(i_clock) and i_reset = '1' then
       null; 
    end if;
end process;



end architecture ; -- arch
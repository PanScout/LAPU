library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package constants is
    constant SCALAR_TO_SCALAR            : std_logic_vector(1 downto 0) := "00";
    constant VECTOR_TO_VECTOR            : std_logic_vector(1 downto 0) := "01";
    constant VECTOR_TO_SCALAR            : std_logic_vector(1 downto 0) := "10";
    constant VECTOR_AND_SCALAR_TO_VECTOR : std_logic_vector(1 downto 0) := "11";

    constant R_TYPE : std_logic_vector(7 downto 0) := x"01";
    constant I_TYPE : std_logic_vector(7 downto 0) := x"02";
    constant J_TYPE : std_logic_vector(7 downto 0) := x"03";
    constant S_TYPE : std_logic_vector(7 downto 0) := x"04";

    constant CNEG    : std_logic_vector(7 downto 0) := x"00";
    constant CCONJ   : std_logic_vector(7 downto 0) := x"01";
    constant CSQRT   : std_logic_vector(7 downto 0) := x"02";
    constant CABS    : std_logic_vector(7 downto 0) := x"03";
    constant CABS2   : std_logic_vector(7 downto 0) := x"04";
    constant CREAL   : std_logic_vector(7 downto 0) := x"05";
    constant CIMAG   : std_logic_vector(7 downto 0) := x"06";
    constant CRECP   : std_logic_vector(7 downto 0) := x"07";
    constant CADD    : std_logic_vector(7 downto 0) := x"08";
    constant CSUB    : std_logic_vector(7 downto 0) := x"09";
    constant CMUL    : std_logic_vector(7 downto 0) := x"0A";
    constant CDIV    : std_logic_vector(7 downto 0) := x"0B";
    constant CMAXABS : std_logic_vector(7 downto 0) := x"0C";
    constant CMINABS : std_logic_vector(7 downto 0) := x"0D";

    constant VADD  : std_logic_vector(7 downto 0) := x"00";
    constant VSUB  : std_logic_vector(7 downto 0) := x"01";
    constant VMUL  : std_logic_vector(7 downto 0) := x"02";
    constant VMAC  : std_logic_vector(7 downto 0) := x"03";
    constant VDIV  : std_logic_vector(7 downto 0) := x"04";
    constant VCONJ : std_logic_vector(7 downto 0) := x"05";

end package constants;

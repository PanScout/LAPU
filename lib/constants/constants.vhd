library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package constants is
    constant SCALAR_TO_SCALAR            : std_logic_vector(1 downto 0) := "00";
    constant VECTOR_TO_VECTOR            : std_logic_vector(1 downto 0) := "01";
    constant VECTOR_TO_SCALAR            : std_logic_vector(1 downto 0) := "10";
    constant VECTOR_AND_SCALAR_TO_VECTOR : std_logic_vector(1 downto 0) := "11";
    constant R_TYPE                      : std_logic_vector(7 downto 0) := x"01";
    constant I_TYPE                      : std_logic_vector(7 downto 0) := x"02";
    constant J_TYPE                      : std_logic_vector(7 downto 0) := x"03";
    constant S_TYPE                      : std_logic_vector(7 downto 0) := x"04";
    constant R_CNEG                      : std_logic_vector(7 downto 0) := x"00";
    constant R_CCONJ                     : std_logic_vector(7 downto 0) := x"01";
    constant R_CSQRT                     : std_logic_vector(7 downto 0) := x"02";
    constant R_CABS                      : std_logic_vector(7 downto 0) := x"03";
    constant R_CABS2                     : std_logic_vector(7 downto 0) := x"04";
    constant R_CREAL                     : std_logic_vector(7 downto 0) := x"05";
    constant R_CIMAG                     : std_logic_vector(7 downto 0) := x"06";
    constant R_CRECP                     : std_logic_vector(7 downto 0) := x"07";
    constant R_CADD                      : std_logic_vector(7 downto 0) := x"08";
    constant R_CSUB                      : std_logic_vector(7 downto 0) := x"09";
    constant R_CMUL                      : std_logic_vector(7 downto 0) := x"0A";
    constant R_CDIV                      : std_logic_vector(7 downto 0) := x"0B";
    constant R_CMAXABS                   : std_logic_vector(7 downto 0) := x"0C";
    constant R_CMINABS                   : std_logic_vector(7 downto 0) := x"0D";
    constant R_VADD                      : std_logic_vector(7 downto 0) := x"00";
    constant R_VSUB                      : std_logic_vector(7 downto 0) := x"01";
    constant R_VMUL                      : std_logic_vector(7 downto 0) := x"02";
    constant R_VMAC                      : std_logic_vector(7 downto 0) := x"03";
    constant R_VDIV                      : std_logic_vector(7 downto 0) := x"04";
    constant R_VCONJ                     : std_logic_vector(7 downto 0) := x"05";

end package constants;

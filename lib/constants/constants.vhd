library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package constants is
    constant SCALAR_TO_SCALAR        : std_logic_vector(1 downto 0) := "00";
    constant VECTOR_TO_VECTOR        : std_logic_vector(1 downto 0) := "01";
    constant VECTOR_TO_SCALAR        : std_logic_vector(1 downto 0) := "10";
    constant VECTOR_SCALAR_BROADCAST : std_logic_vector(1 downto 0) := "11";

    constant R_TYPE    : std_logic_vector(7 downto 0) := x"01";
    constant I_TYPE    : std_logic_vector(7 downto 0) := x"02";
    constant J_TYPE    : std_logic_vector(7 downto 0) := x"03";
    constant S_TYPE    : std_logic_vector(7 downto 0) := x"04";
    constant R_CNEG    : std_logic_vector(7 downto 0) := x"00";
    constant R_CCONJ   : std_logic_vector(7 downto 0) := x"01";
    constant R_CSQRT   : std_logic_vector(7 downto 0) := x"02";
    constant R_CABS    : std_logic_vector(7 downto 0) := x"03";
    constant R_CABS2   : std_logic_vector(7 downto 0) := x"04";
    constant R_CREAL   : std_logic_vector(7 downto 0) := x"05";
    constant R_CIMAG   : std_logic_vector(7 downto 0) := x"06";
    constant R_CRECP   : std_logic_vector(7 downto 0) := x"07";
    constant R_CADD    : std_logic_vector(7 downto 0) := x"08";
    constant R_CSUB    : std_logic_vector(7 downto 0) := x"09";
    constant R_CMUL    : std_logic_vector(7 downto 0) := x"0A";
    constant R_CDIV    : std_logic_vector(7 downto 0) := x"0B";
    constant R_CMAXABS : std_logic_vector(7 downto 0) := x"0C";
    constant R_CMINABS : std_logic_vector(7 downto 0) := x"0D";
    constant R_VADD    : std_logic_vector(7 downto 0) := x"00";
    constant R_VSUB    : std_logic_vector(7 downto 0) := x"01";
    constant R_VMUL    : std_logic_vector(7 downto 0) := x"02";
    constant R_VMAC    : std_logic_vector(7 downto 0) := x"03";
    constant R_VDIV    : std_logic_vector(7 downto 0) := x"04";
    constant R_VCONJ   : std_logic_vector(7 downto 0) := x"05";
    constant I_CLOADI  : std_logic_vector(7 downto 0) := x"00";
    constant I_CADDI   : std_logic_vector(7 downto 0) := x"01";
    constant I_CMULI   : std_logic_vector(7 downto 0) := x"02";
    constant I_CSUB    : std_logic_vector(7 downto 0) := x"03";
    constant I_CDIVI   : std_logic_vector(7 downto 0) := x"04";
    constant I_MAXABSI : std_logic_vector(7 downto 0) := x"05";
    constant I_MINABSI : std_logic_vector(7 downto 0) := x"06";

    constant ALU_NEGATION    : std_logic_vector(7 downto 0) := x"00";
    constant ALU_CONJUGATION : std_logic_vector(7 downto 0) := x"01";
    constant ALU_SQRT        : std_logic_vector(7 downto 0) := x"02";
    constant ALU_ABSOLUTE2   : std_logic_vector(7 downto 0) := x"03";
    constant ALU_ABSOLUTE    : std_logic_vector(7 downto 0) := x"04";
    constant ALU_REAL        : std_logic_vector(7 downto 0) := x"05";
    constant ALU_IMAG        : std_logic_vector(7 downto 0) := x"06";
    constant ALU_RECIP       : std_logic_vector(7 downto 0) := x"07";
    constant ALU_ADD         : std_logic_vector(7 downto 0) := x"08";
    constant ALU_SUB         : std_logic_vector(7 downto 0) := x"09";
    constant ALU_MUL         : std_logic_vector(7 downto 0) := x"0A";
    constant ALU_DIV         : std_logic_vector(7 downto 0) := x"0B";

    constant ALU_DOT : std_logic_vector(7 downto 0) := x"00";
    constant ALU_MAX : std_logic_vector(7 downto 0) := x"01";
    constant ALU_SUM : std_logic_vector(7 downto 0) := x"02";

    constant ALU_VADD : std_logic_vector(7 downto 0) := x"00";
    constant ALU_VSUB : std_logic_vector(7 downto 0) := x"01";
    constant ALU_VMUL : std_logic_vector(7 downto 0) := x"02";
    constant ALU_VMAC : std_logic_vector(7 downto 0) := x"03";
    constant ALU_VDIV : std_logic_vector(7 downto 0) := x"04";
    constant ALU_VCONJ : std_logic_vector(7 downto 0) := x"05";

    constant ALU_VSADD : std_logic_vector(7 downto 0) := x"00";
    constant ALU_VSSUB : std_logic_vector(7 downto 0) := x"01";
    constant ALU_VSMUL : std_logic_vector(7 downto 0) := x"02";
    constant ALU_VSDIV : std_logic_vector(7 downto 0) := x"03";

    constant S_VLD : std_logic_vector(7 downto 0) := x"00";
    constant S_VST : std_logic_vector(7 downto 0) := x"01";
    constant S_SLD : std_logic_vector(7 downto 0) := x"02";
    constant S_SST : std_logic_vector(7 downto 0) := x"03";

    

end package constants;

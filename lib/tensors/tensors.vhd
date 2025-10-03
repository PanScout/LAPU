library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library fixed_pkg;
use fixed_pkg.fixed_pkg.all;

package tensors is
    constant FIXED_INT_BITS  : integer := 32;
    constant FIXED_FRAC_BITS : integer := -32;
    constant FIXED_BIT_SIZE  : integer := FIXED_INT_BITS - FIXED_FRAC_BITS; -- 64
    constant VECTOR_SIZE     : integer := 8;

    subtype sfix_t is sfixed((FIXED_INT_BITS - 1) downto FIXED_FRAC_BITS);
    type complex_t is record
        re : sfix_t;
        im : sfix_t;
    end record complex_t;
    type vector_t is array (VECTOR_SIZE - 1 downto 0) of complex_t;
    type matrix_t is array (VECTOR_SIZE - 1 downto 0) of vector_t;
    --Complex Numbers!
    function make_complex(A, B : real) return complex_t;
    function "+"(A, B : complex_t) return complex_t;
    function "-"(A, B : complex_t) return complex_t;
    function "*"(A, B : complex_t) return complex_t;
    function "/"(A, B : complex_t) return complex_t;
    function conj(A: complex_t) return complex_t;
    --Vectors

    --Matrices
end package tensors;

package body tensors is
    -------------------------------
    --- HELPER FUNCTIONS (local) ---
    -------------------------------

    -- 1) Unambiguous narrowing back to sfix_t
    function fit(A : sfixed) return sfix_t is
    begin
        return resize(A, (FIXED_INT_BITS - 1), FIXED_FRAC_BITS);
    end function fit;

    function to_sfixed(A : real) return sfix_t is
    begin
        return to_sfixed(A, (FIXED_INT_BITS - 1), FIXED_FRAC_BITS);
    end function to_sfixed;

    -- 2) Raw helpers on sfixed. These call the library operators (no overloading here).
    function sf_add(L, R : sfixed) return sfixed is
    begin
        return L + R;
    end function;

    function sf_sub(L, R : sfixed) return sfixed is
    begin
        return L - R;
    end function;

    function sf_mul(L, R : sfixed) return sfixed is
    begin
        return L * R;
    end function;

    function sf_div(L, R : sfixed) return sfixed is
    begin
        return L / R;
    end function;

    -- 3) sfix_t operator overloads, implemented via raw sfixed helpers + fit()
    function "+"(L, R : sfix_t) return sfix_t is
    begin
        return fit(sf_add(sfixed(L), sfixed(R)));
    end function;

    function "-"(L, R : sfix_t) return sfix_t is
    begin
        return fit(sf_sub(sfixed(L), sfixed(R)));
    end function;

    function "-"(R : sfix_t) return sfix_t is -- unary minus
    begin
        return fit(-sfixed(R));
    end function;

    function "*"(L, R : sfix_t) return sfix_t is
    begin
        return fit(sf_mul(sfixed(L), sfixed(R)));
    end function;

    function "/"(L, R : sfix_t) return sfix_t is
    begin
        return fit(sf_div(sfixed(L), sfixed(R)));
    end function;

    -----------------------------
    ----- PUBLIC FUNCTIONS -------
    -----------------------------

    function make_complex(A, B : real) return complex_t is
        variable ret : complex_t;
    begin
        ret.re := to_sfixed(A);
        ret.im := to_sfixed(B);
        return ret;
    end function make_complex;

    function "+"(A, B : complex_t) return complex_t is
        variable ret : complex_t;
    begin
        ret.re := A.re + B.re;
        ret.im := A.im + B.im;
        return ret;
    end function "+";

    function "-"(A, B : complex_t) return complex_t is
        variable ret : complex_t;
    begin
        ret.re := A.re - B.re;
        ret.im := A.im - B.im;
        return ret;
    end function "-";

    -- Gauss 3-multiply:
    -- m1 = a*c; m2 = b*d; m3 = (a+b)*(c+d)
    -- Re = m1 - m2; Im = m3 - m1 - m2
    function "*"(A, B : complex_t) return complex_t is
        variable m1, m2, m3 : sfix_t;
        variable ret        : complex_t;
    begin
        m1     := A.re * B.re;
        m2     := A.im * B.im;
        m3     := (A.re + A.im) * (B.re + B.im);
        ret.re := m1 - m2;
        ret.im := (m3 - m1) - m2;
        return ret;
    end function "*";

    -- Smith/Kahan-style robust complex division:
    -- If |c| >= |d|: t = d/c; den = c + d*t; Re=(a + b*t)/den; Im=(b - a*t)/den
    -- else:         t = c/d; den = d + c*t; Re=(a*t + b)/den; Im=(b*t - a)/den
    function "/"(A, B : complex_t) return complex_t is
        variable t, den : sfix_t;
        variable ret    : complex_t;
    begin
        if abs (B.re) >= abs (B.im) then
            t      := B.im / B.re;
            den    := B.re + (B.im * t);
            ret.re := (A.re + (A.im * t)) / den;
            ret.im := (A.im - (A.re * t)) / den;
        else
            t      := B.re / B.im;
            den    := B.im + (B.re * t);
            ret.re := ((A.re * t) + A.im) / den;
            ret.im := ((A.im * t) - A.re) / den;
        end if;
        return ret;
    end function "/";

    function conj(A: complex_t)
        return complex_t is
        variable ret : complex_t;
    begin
        ret.re := A.re;
        ret.im := -1 * A.im;
        return ret;
    end function conj;
    

end package body tensors;

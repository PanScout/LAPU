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
    constant MATRIX_FACTOR   : integer := 2;

    subtype sfix_t is sfixed((FIXED_INT_BITS - 1) downto FIXED_FRAC_BITS);

    type complex_t is record
        re : sfix_t;
        im : sfix_t;
    end record complex_t;

    type vector_t is array (VECTOR_SIZE - 1 downto 0) of complex_t;
    type matrix_t is array ((VECTOR_SIZE * MATRIX_FACTOR) - 1 downto 0, (VECTOR_SIZE * MATRIX_FACTOR) - 1 downto 0) of complex_t;

    constant COMPLEX_ZERO : complex_t := ((others => (others => '0')));
    constant VECTOR_ZERO  : vector_t  := ((others => (others => (others => '0'))));

    --Complex Numbers!
    function make_complex(A, B : real) return complex_t;
    function make_complex(A, B : natural) return complex_t;
    function "+"(A, B : complex_t) return complex_t;
    function "-"(A, B : complex_t) return complex_t;
    function neg(A : complex_t) return complex_t;
    function "*"(A, B : complex_t) return complex_t;
    function "/"(A, B : complex_t) return complex_t;
    function conj(A : complex_t) return complex_t;
    function abs2(A : complex_t) return complex_t;
    function sqrt(A : complex_t) return complex_t;
    function "abs"(A : complex_t) return complex_t;
    function ">"(A, B : complex_t) return boolean;
    function "<"(A, B : complex_t) return boolean;

    --Vectors
    function make_vector(A, B, C, D, E, F, G, H : complex_t) return vector_t;
    function vadd(A, B : vector_t) return vector_t;
    function vsub(A, B : vector_t) return vector_t;
    function vmul(A, B : vector_t) return vector_t;
    function vdiv(A, B : vector_t) return vector_t;
    function vlaneconj(A : vector_t) return vector_t;
    function vdot(A, B : vector_t) return complex_t;
    function vmax(A : vector_t) return complex_t;
    function vsum(A : vector_t) return complex_t;

    --Vector Times Scalar
    function vlaneadd(A : vector_t; B : complex_t) return vector_t;
    function vlanesub(A : vector_t; B : complex_t) return vector_t;
    function vlanemul(A : vector_t; B : complex_t) return vector_t;
    function vlanediv(A : vector_t; B : complex_t) return vector_t;

    --Matrices
end package tensors;

package body tensors is
    -------------------------------
    --- HELPER FUNCTIONS (local) ---
    -------------------------------

    function fit(A : sfixed) return sfix_t is
    begin
        return resize(A, (FIXED_INT_BITS - 1), FIXED_FRAC_BITS);
    end function fit;

    function to_sfixed(A : real) return sfix_t is
    begin
        return to_sfixed(A, (FIXED_INT_BITS - 1), FIXED_FRAC_BITS);
    end function to_sfixed;

    function to_sfixed(A : natural) return sfix_t is
    begin
        return to_sfixed(A, (FIXED_INT_BITS - 1), FIXED_FRAC_BITS);
    end function to_sfixed;

    function sqrt_sfix(A : sfix_t) return sfix_t is
        variable ret : sfix_t := (others => '0');

        -- Working vars
        variable t      : sfix_t;       -- input copy (nonnegative)
        variable g, tmp : sfix_t;       -- NR iterate and temp
        variable idx    : integer;      -- msb index of A
        variable g_idx  : integer;      -- seed index for g = 2^ceil(idx/2)

        constant SFIX_ZERO : sfix_t := (others => '0');
    begin
        -- Clamp negatives to zero (sqrt undefined)
        if A <= SFIX_ZERO then
            return ret;
        end if;

        t := A;                         -- t > 0 here

        -- ----- Seed g ≈ 2^ceil(msb_index(t)/2) -----
        -- Scan for the highest '1' bit in t
        idx := t'low;                   -- default if sub-LSB magnitudes
        for i in t'high downto t'low loop
            if t(i) = '1' then
                idx := i;
                exit;
            end if;
        end loop;

        -- Compute ceil(idx/2) with VHDL integer division semantics (toward zero)
        if idx >= 0 then
            g_idx := idx / 2 + (idx mod 2); -- ceil for nonnegative idx
        else
            g_idx := idx / 2;           -- division toward zero acts like ceil for negatives
        end if;

        -- Create power-of-two seed g = 2^g_idx (bounded to vector range)
        g        := (others => '0');
        if g_idx > g'high then
            g_idx := g'high;
        elsif g_idx < g'low then
            g_idx := g'low;
        end if;
        g(g_idx) := '1';
        -- Fallback seed if something went sideways
        if g = SFIX_ZERO then
            g(0) := '1';                -- 1.0
        end if;

        -- ----- Two Newton–Raphson iterations: g_{n+1} = 0.5*(g_n + t/g_n) -----
        -- 1st iteration
        tmp := resize(t / g, g'high, g'low);
        g   := resize((g + tmp) / 2, g'high, g'low);

        -- 2nd iteration
        tmp := resize(t / g, g'high, g'low);
        g   := resize((g + tmp) / 2, g'high, g'low);

        ret := resize(g, ret'high, ret'low);
        return ret;
    end function;

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
        return fit(L / R);
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
        return fit(fixed_pkg.fixed_pkg."-"(sfixed(R)));
    end function;

    function "*"(L, R : sfix_t) return sfix_t is
    begin
        return fit(sf_mul(sfixed(L), sfixed(R)));
    end function;

    function "/"(L, R : sfix_t) return sfix_t is
    begin
        return fit(sf_div(sfixed(L), sfixed(R)));
    end function;

    ------------------------------
    ----- PUBLIC FUNCTIONS -------
    ------------------------------
    function make_complex(A, B : real) return complex_t is
        variable ret : complex_t;
    begin
        ret.re := to_sfixed(A);
        ret.im := to_sfixed(B);
        return ret;
    end function make_complex;

    function make_complex(A, B : natural) return complex_t is
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

    function neg(A : complex_t) return complex_t is
        variable ret : complex_t;
    begin
        ret.re := -A.re;
        ret.im := -A.im;
        return ret;
    end function neg;

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

    function "abs"(A : complex_t) return complex_t is
        variable X   : sfix_t    := (others => '0');
        variable Y   : sfix_t    := (others => '0');
        variable X_Y : sfix_t    := ((others => '0'));
        variable ret : complex_t := COMPLEX_ZERO;
    begin
        X      := A.re * A.re;
        Y      := A.im * A.im;
        X_Y    := X + Y;
        ret.re := sqrt_sfix(X_Y);
        return ret;
    end function "abs";

    function vdot(A, B : vector_t)
    return complex_t is
        variable sum : complex_t := COMPLEX_ZERO;
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            sum := A(i) + B(i);
        end loop;
        return sum;
    end function vdot;

    function ">"(A, B : complex_t)
    return boolean is
    begin
        if (abs (A) > abs (B)) then
            return true;
        end if;

        return false;

    end function ">";

    function "<"(A, B : complex_t)
    return boolean is
    begin
        if (abs (A) > abs (B)) then
            return false;
        end if;

        return true;
    end function "<";

    function conj(A : complex_t)
    return complex_t is
        variable ret     : complex_t;
        constant NEG_ONE : sfix_t := to_sfixed(-1.0);
    begin
        ret.re := A.re;
        ret.im := NEG_ONE * A.im;
        return ret;
    end function conj;

    function abs2(A : complex_t)
    return complex_t is
        variable ret : complex_t;
    begin
        ret.re := (A.re * A.re) + (A.im * A.im);
        ret.im := (others => '0');
        return ret;
    end function abs2;

    function sqrt(A : complex_t) return complex_t is
        variable ret : complex_t := COMPLEX_ZERO;

        -- Shorthand/temps
        variable x, y       : sfix_t;
        variable ax, ay     : sfix_t;
        variable maxv, minv : sfix_t;
        variable r          : sfix_t;   -- |z| approx
        variable t          : sfix_t;   -- scalar whose sqrt we compute
        variable s          : sfix_t;   -- sqrt(t) approx
        variable g, tmp     : sfix_t;   -- NR working vars

        -- Leading-one / seed indices
        variable idx   : integer;
        variable g_idx : integer;

        -- Local zero
        constant SFIX_ZERO : sfix_t := (others => '0');
    begin
        x := A.re;
        y := A.im;

        -- Trivial zero
        if (x = SFIX_ZERO) and (y = SFIX_ZERO) then
            return ret;
        end if;

        -- |x|, |y|
        if x < SFIX_ZERO then
            ax := -x;
        else
            ax := x;
        end if;
        if y < SFIX_ZERO then
            ay := -y;
        else
            ay := y;
        end if;

        -- α-max + β-min magnitude estimate (α=1, β=1/2)
        if ax >= ay then
            maxv := ax;
            minv := ay;
        else
            maxv := ay;
            minv := ax;
        end if;
        r := resize(maxv + (minv / 2), ret.re'high, ret.re'low);

        if x >= SFIX_ZERO then
            -- For x >= 0:
            --   u = sqrt((r + x)/2);  v = y / (2u)
            t := resize((r + x) / 2, ret.re'high, ret.re'low);

            -- ---- sqrt(t) via 2-step Newton-Raphson with bit-seeded guess ----
            if t <= SFIX_ZERO then
                s := SFIX_ZERO;
            else
                -- Seed g = 2^ceil(msb_index(t)/2)
                g   := (others => '0');
                idx := t'low;           -- default if t is sub-LSB

                for i in t'high downto t'low loop
                    if t(i) = '1' then
                        idx := i;
                        exit;
                    end if;
                end loop;

                if idx >= 0 then
                    g_idx := idx / 2 + (idx mod 2); -- ceil(idx/2) for nonnegative idx
                else
                    g_idx := idx / 2;   -- trunc toward zero ≈ ceil for negatives
                end if;

                if g_idx > g'high then
                    g_idx := g'high;
                end if;
                if g_idx < g'low then
                    g_idx := g'low;
                end if;
                g(g_idx) := '1';
                if g = SFIX_ZERO then
                    g(0) := '1';        -- fallback seed = 1.0
                end if;

                -- Two NR iterations: g = 0.5*(g + t/g)
                tmp := resize(t / g, g'high, g'low);
                g   := resize((g + tmp) / 2, g'high, g'low);
                tmp := resize(t / g, g'high, g'low);
                g   := resize((g + tmp) / 2, g'high, g'low);

                s := g;
            end if;

            ret.re := s;
            if s /= SFIX_ZERO then
                ret.im := resize(y / (s + s), ret.im'high, ret.im'low); -- y/(2u)
            else
                ret.im := SFIX_ZERO;
            end if;

        else
            -- For x < 0:
            --   v = sign(y)*sqrt((r - x)/2);  u = |y| / (2|v|)
            t := resize((r - x) / 2, ret.re'high, ret.re'low);

            -- ---- sqrt(t) via same 2-step NR ----
            if t <= SFIX_ZERO then
                s := SFIX_ZERO;
            else
                g   := (others => '0');
                idx := t'low;

                for i in t'high downto t'low loop
                    if t(i) = '1' then
                        idx := i;
                        exit;
                    end if;
                end loop;

                if idx >= 0 then
                    g_idx := idx / 2 + (idx mod 2);
                else
                    g_idx := idx / 2;
                end if;

                if g_idx > g'high then
                    g_idx := g'high;
                end if;
                if g_idx < g'low then
                    g_idx := g'low;
                end if;
                g(g_idx) := '1';
                if g = SFIX_ZERO then
                    g(0) := '1';
                end if;

                tmp := resize(t / g, g'high, g'low);
                g   := resize((g + tmp) / 2, g'high, g'low);
                tmp := resize(t / g, g'high, g'low);
                g   := resize((g + tmp) / 2, g'high, g'low);

                s := g;
            end if;

            if y < SFIX_ZERO then
                ret.im := -s;           -- sign(y)*sqrt(...)
            else
                ret.im := s;
            end if;

            if s /= SFIX_ZERO then
                ret.re := resize(ay / (s + s), ret.re'high, ret.re'low); -- |y|/(2|v|)
            else
                ret.re := SFIX_ZERO;
            end if;
        end if;

        return ret;
    end function;

    ------------------------------
    -----------VECTORS------------
    ------------------------------

    function make_vector(A, B, C, D, E, F, G, H : complex_t)
    return vector_t is
        variable ret : vector_t;

    begin
        ret(0) := A;
        ret(1) := B;
        ret(2) := C;
        ret(3) := D;
        ret(4) := E;
        ret(5) := F;
        ret(6) := G;
        ret(7) := H;
        return ret;
    end function make_vector;

    function vadd(A, B : vector_t)
    return vector_t is
        variable ret : vector_t := (others => ((others => ((others => '0')))));
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            ret(i) := A(i) + B(i);
        end loop;
        return ret;
    end function vadd;

    function vsub(A, B : vector_t)
    return vector_t is
        variable ret : vector_t := (others => ((others => ((others => '0')))));
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            ret(i) := A(i) - B(i);
        end loop;
        return ret;
    end function vsub;

    function vmul(A, B : vector_t)
    return vector_t is
        variable ret : vector_t;
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            ret(i) := A(i) * B(i);
        end loop;
        return ret;
    end function vmul;

    function vdiv(A, B : vector_t)
    return vector_t is
        variable ret : vector_t;
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            ret(i) := A(i) / B(i);
        end loop;
        return ret;
    end function vdiv;

    function vlaneconj(A : vector_t)
    return vector_t is
        variable ret : vector_t;
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            ret(i) := conj(A(i));
        end loop;
        return ret;
    end function vlaneconj;

    function vmax(A : vector_t)
    return complex_t is
        variable curr_max : complex_t := abs (A(0));
    begin
        for i in 1 to VECTOR_SIZE - 1 loop
            if (abs (A(i)) > abs (curr_max)) then
                curr_max := A(i);
            end if;
        end loop;
        return curr_max;
    end function vmax;

    function vsum(A : vector_t)
    return complex_t is
        variable sum : complex_t := COMPLEX_ZERO;
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            sum := sum + A(i);
        end loop;

        return sum;
    end function vsum;

    function vasum(A : vector_t)
    return complex_t is
        variable sum : complex_t := COMPLEX_ZERO;
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            sum := abs(sum) + abs(A(i));
        end loop;

        return sum;
    end function vasum;


    -------------------------------------------
    -----------VECTORS TIMES SCALAR------------
    -------------------------------------------

    function vlaneadd(A : vector_t; B : complex_t) return vector_t is
        variable ret : vector_t;
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            ret(i) := A(i) + B;
        end loop;
        return ret;
    end;

    function vlanesub(A : vector_t; B : complex_t) return vector_t is
        variable ret : vector_t;
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            ret(i) := A(i) - B;
        end loop;
        return ret;
    end;

    function vlanemul(A : vector_t; B : complex_t) return vector_t is
        variable ret : vector_t;
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            ret(i) := A(i) * B;
        end loop;
        return ret;
    end;

    function vlanediv(A : vector_t; B : complex_t) return vector_t is
        variable ret : vector_t;
    begin
        for i in 0 to VECTOR_SIZE - 1 loop
            ret(i) := A(i) / B;
        end loop;
        return ret;
    end;

end package body tensors;

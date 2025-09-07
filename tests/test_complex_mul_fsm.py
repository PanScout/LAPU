# tests/test_complex_mul.py
# Cocotb testbench for complex_mul_fsm (3-cycle Gauss FSM multiplier).
# Uses a local fixed-point reference (Q format with blind truncation).
#
# Handshake:
#   - Drive i_start=1 for one clk when o_ready=1 with i_a/i_b stable.
#   - Expect o_valid=1 exactly one cycle in S_OUT; read o_y then.

import os
from typing import Tuple, List

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# -------------------------------
# Config: must match VHDL package
# -------------------------------
PART_FRAC_BITS = int(os.getenv("PART_FRAC_BITS", "32"))  # keep in sync with VHDL

# -------------------------------
# Bit helpers (two's complement)
# -------------------------------
def mask(width: int) -> int:
    return (1 << width) - 1

def int_to_twos(x: int, width: int) -> int:
    return x & mask(width)

def twos_to_int(x: int, width: int) -> int:
    # interpret x (0..2^width-1) as signed
    sign_bit = 1 << (width - 1)
    return (x & (sign_bit - 1)) - (x & sign_bit)

# ---------------------------------------
# Q-format helpers (pack/unpack complex)
# ---------------------------------------
def part_from_int(n: int, part_w: int) -> int:
    """Encode integer n into Q(int.frac) with FRAC=PART_FRAC_BITS."""
    return int_to_twos(n << PART_FRAC_BITS, part_w)

def pack_complex(re_bits: int, im_bits: int, part_w: int) -> int:
    """Pack [REAL|IMAG] into COMPLEX_WIDTH=2*part_w."""
    return int_to_twos((re_bits << part_w) | im_bits, 2 * part_w)

def unpack_complex(x: int, part_w: int) -> Tuple[int, int]:
    """Unpack signed parts from [REAL|IMAG]. Returns (re_bits_signed, im_bits_signed)."""
    im_raw = x & mask(part_w)
    re_raw = (x >> part_w) & mask(part_w)
    return twos_to_int(re_raw, part_w), twos_to_int(im_raw, part_w)

# -------------------------------------------------
# Fixed-point multiply: (a*b) >> FRAC, truncate
# inputs/outputs are signed PART_WIDTH integers
# -------------------------------------------------
def fx_mul_trunc_q(a_bits: int, b_bits: int, part_w: int) -> int:
    prod_full = a_bits * b_bits  # Python big int holds 2W
    prod_shift = prod_full >> PART_FRAC_BITS  # arithmetic shift (Python does sign-preserving)
    return int_to_twos(prod_shift, part_w)

# -------------------------------------------------
# Reference complex multiply (4 real multiplies)
# -------------------------------------------------
def ref_complex_mul(a_re_bits: int, a_im_bits: int, b_re_bits: int, b_im_bits: int, part_w: int) -> Tuple[int, int]:
    ac = fx_mul_trunc_q(a_re_bits, b_re_bits, part_w)
    bd = fx_mul_trunc_q(a_im_bits, b_im_bits, part_w)
    ad = fx_mul_trunc_q(a_re_bits, b_im_bits, part_w)
    bc = fx_mul_trunc_q(a_im_bits, b_re_bits, part_w)
    re = int_to_twos((twos_to_int(ac, part_w) - twos_to_int(bd, part_w)), part_w)
    im = int_to_twos((twos_to_int(ad, part_w) + twos_to_int(bc, part_w)), part_w)
    return re, im

# ---------------------------------------
# Test coroutine
# ---------------------------------------
@cocotb.test()
async def test_complex_mul_basic(dut):
    """
    Drive several vectors through the 3-cycle FSM using the ready/start/valid protocol
    and compare o_y against the local bit-exact reference.
    """
    # Derive widths from the DUT ports (portable across simulators).
    complex_w = len(dut.i_a)
    part_w = complex_w // 2

    # Start a 2 ns period clock (common in cocotb examples).  :contentReference[oaicite:1]{index=1}
    cocotb.start_soon(Clock(dut.i_clk, 2, units="ns").start())

    # Synchronous reset (active-high)
    dut.i_rst.value = 1
    dut.i_start.value = 0
    dut.i_a.value = 0
    dut.i_b.value = 0
    for _ in range(3):
        await RisingEdge(dut.i_clk)
    dut.i_rst.value = 0

    # Helper: run one stimulus & check
    async def do_case(name: str, a_re_i: int, a_im_i: int, b_re_i: int, b_im_i: int):
        # Form Q-format parts
        a_re_bits = part_from_int(a_re_i, part_w)
        a_im_bits = part_from_int(a_im_i, part_w)
        b_re_bits = part_from_int(b_re_i, part_w)
        b_im_bits = part_from_int(b_im_i, part_w)

        # Golden
        exp_re_bits, exp_im_bits = ref_complex_mul(
            twos_to_int(a_re_bits, part_w),
            twos_to_int(a_im_bits, part_w),
            twos_to_int(b_re_bits, part_w),
            twos_to_int(b_im_bits, part_w),
            part_w,
        )

        # Wait for o_ready clocked-high (robust even if it's already 1)  :contentReference[oaicite:2]{index=2}
        while not int(dut.o_ready.value):
            await RisingEdge(dut.i_clk)

        # Drive inputs
        dut.i_a.value = pack_complex(a_re_bits, a_im_bits, part_w)
        dut.i_b.value = pack_complex(b_re_bits, b_im_bits, part_w)

        # Pulse start for one cycle
        dut.i_start.value = 1
        await RisingEdge(dut.i_clk)
        dut.i_start.value = 0

        # Wait for o_valid (up to a small timeout)
        timeout = 50
        while not int(dut.o_valid.value):
            await RisingEdge(dut.i_clk)
            timeout -= 1
            if timeout == 0:
                assert False, f"Timeout waiting for o_valid in {name}"

        # Read result and compare
        got = int(dut.o_y.value)  # BinaryValue → int is standard per cocotb API. :contentReference[oaicite:3]{index=3}
        got_re_bits, got_im_bits = unpack_complex(got, part_w)

        assert got_re_bits == twos_to_int(exp_re_bits, part_w), f"{name}: RE mismatch"
        assert got_im_bits == twos_to_int(exp_im_bits, part_w), f"{name}: IM mismatch"

        dut._log.info(f"PASS: {name}")

        # spacer cycle for nice waves
        await RisingEdge(dut.i_clk)

    # Vectors (same ones you used in your VHDL TB)
    tests: List[Tuple[str, int, int, int, int]] = [
        ("T1 (1+2i)*(-3+4i) -> (-11-2i)",   1,  2,  -3,  4),
        ("T2 (3-1i)*(2+5i)  -> (11+13i)",  3, -1,   2,  5),
        ("T3 (0+0i)*(7-8i)  -> (0+0i)",    0,  0,   7, -8),
        ("T4 (-1-1i)*(-1-1i)-> (0+2i)",   -1, -1,  -1, -1),
    ]
    for t in tests:
        await do_case(*t)

    dut._log.info("All complex_mul_fsm tests passed.")

# -------------------------------------------------------------
# Optional: enable "python -m tests.test_complex_mul" via runner
# -------------------------------------------------------------
if __name__ == "__main__":
    # Use your provided helper; defaults to src/**/*.vhd.  :contentReference[oaicite:4]{index=4}
    from _runner import run_cocotb
    run_cocotb(
        __file__,
        dut="complex_mul_fsm",
        # sources=None -> your helper auto-discovers VHDL under src/
        waves=bool(int(os.getenv("WAVES", "0"))),  # also supported by cocotb runners. :contentReference[oaicite:5]{index=5}
        test_args=os.getenv("TEST_ARGS", "").split() if os.getenv("TEST_ARGS") else None,
        parameters=None,  # map VHDL generics here if you add any
    )

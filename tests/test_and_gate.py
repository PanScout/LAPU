# tests/test_and_gate.py
import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def check_and(dut):
    for a, b, exp in [("0","0","0"), ("0","1","0"), ("1","0","0"), ("1","1","1")]:
        dut.a.value = int(a)
        dut.b.value = int(b)
        await Timer(10, units="ns")
        assert int(dut.y.value) == int(exp)

if __name__ == "__main__":
    from _runner import run_cocotb
    run_cocotb(__file__, dut="and_gate")  # auto-collects src/**/*.vhd, no waves

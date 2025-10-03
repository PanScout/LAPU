
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from cocotb.regression import TestFactory

@cocotb.test()
async def run_test(dut):
  PERIOD = 10

  dut.i_clock = 0
  dut.i_reset = 0
  dut.i_matrix_sel = 0
  dut.i_scalar_or_vector_action = 0
  dut.i_rw_vector = 0
  dut.i_column_or_row_order = 0
  dut.i_vector_i = 0
  dut.i_vector_j = 0
  dut.i_vector = 0
  dut.i_rw_scalar = 0
  dut.i_scalar_i = 0
  dut.i_scalar_j = 0
  dut.i_scalar = 0


  await Timer(20*PERIOD, units='ns')
  o_vector = dut.o_vector.value
  o_scalar = dut.o_scalar.value


  dut.i_clock = 0
  dut.i_reset = 0
  dut.i_matrix_sel = 0
  dut.i_scalar_or_vector_action = 0
  dut.i_rw_vector = 0
  dut.i_column_or_row_order = 0
  dut.i_vector_i = 0
  dut.i_vector_j = 0
  dut.i_vector = 0
  dut.i_rw_scalar = 0
  dut.i_scalar_i = 0
  dut.i_scalar_j = 0
  dut.i_scalar = 0


  await Timer(20*PERIOD, units='ns')
  o_vector = dut.o_vector.value
  o_scalar = dut.o_scalar.value


# Register the test.
factory = TestFactory(run_test)
factory.generate_tests()

if __name__ == "__main__":
    from _runner import run_cocotb
    run_cocotb(__file__, dut="and_gate")  # auto-collects src/**/*.vhd, no waves

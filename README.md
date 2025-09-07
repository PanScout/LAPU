# Overview

This is a generic template for GHDL projects. Two ways to use it:

1. **Pure GHDL:** `make clean && make`
2. **Python (cocotb runner):** run a Python test in `tests/` (e.g., `python test_and_gate.py`(make sure you are using the .venv python))

---

## Layout

```
.
├─ src/               # HDL sources (DUT, packages used by DUT)
├─ tb/                # VHDL testbenches (GHDL-only)
├─ lib/<name>/        # Optional VHDL libraries (packages/entities)
├─ tests/             # Python cocotb tests (+ optional _runner.py helper)
├─ build/             # Artifacts: obj/bin/waves/runner
└─ Makefile
```

---

## Quick start

### GHDL flow

```bash
make clean && make                      # uses TB=tb_top by default
```

* **TB**: top-level VHDL testbench entity (in `tb/`).
* **DUMP**: `fst|vcd|ghw` waveform (default `fst`).
* Waves go to `build/waves/`.

### Python (cocotb runner)

```bash
make cocotb                    # bootstraps .venv and installs requirements
```

* Tests use cocotb and call the runner from `__main__` (e.g., `run_cocotb(__file__, dut="and_gate")`).
* Prints/logging/asserts work like normal Python; wave dumps are off unless you enable them in the runner.

---

## Libraries (`lib/`)

* Create `lib/<libname>/` and add VHDL files.
* In HDL, reference with:

  ```vhdl
  library <libname>;
  use <libname>.<pkg_name>.all;
  ```
* **GHDL flow:** Makefile auto-discovers and compiles each `lib/<libname>` as its own library before `work`.
* **Python runner:** include any needed library files in your runner’s source list (or place the required packages under `src/` if you prefer the default `src/**/*.vhd` discovery).

---

## Common targets

* `make` / `make run` – analyze/elaborate/run GHDL TB.
* `make wave` – alias of `run`.
* `make clean` – remove objects/waves for current work.
* `make distclean` – remove `build/`.
* `make cocotb` – set up `.venv` + deps (for Python workflow).
* `make py FILE=…` / `make pytest` – run Python tests.

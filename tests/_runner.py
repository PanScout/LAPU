# tests/_runner.py
from __future__ import annotations
from pathlib import Path
from typing import Iterable, Mapping, Sequence, Union, Optional
from cocotb.runner import get_runner  # cocotb’s Python runner API

Pathish = Union[str, Path]

def _normalize_sources(proj: Path, sources: Optional[Iterable[Pathish]]) -> list[str]:
    if sources is None:
        # default: all VHDL sources under src/
        return [str(p) for p in sorted((proj / "src").rglob("*.vhd"))]
    out: list[str] = []
    for s in sources:
        p = Path(s)
        out.append(str(p if p.is_absolute() else (proj / p)))
    return out

def run_cocotb(
    pyfile: Pathish,                 # __file__ of the test module
    dut: str,                        # HDL toplevel entity name (e.g., "and_gate")
    sources: Optional[Iterable[Pathish]] = None,  # VHDL files (defaults to src/**/*.vhd)
    build_subdir: str = "build/runner",
    waves: bool = False,             # leave False for "no wave dumps"
    parameters: Optional[Mapping[str, object]] = None,  # VHDL generics
    test_args: Optional[Sequence[str]] = None,   # extra args straight to simulator (e.g., ["--stop-time=200ns"])
) -> None:
    """
    Minimal, portable wrapper around cocotb’s Python runner.
    Usage in a test file:
        if __name__ == "__main__":
            from _runner import run_cocotb
            run_cocotb(__file__, dut="and_gate")
    """
    mod_path = Path(pyfile).resolve()
    proj = mod_path.parents[1]            # repo root (…/your_repo/)
    test_module = mod_path.stem           # filename without .py (e.g., "test_and_gate")
    build_dir = proj / build_subdir
    build_dir.mkdir(parents=True, exist_ok=True)

    vhdl_sources = _normalize_sources(proj, sources)
    params = dict(parameters or {})
    extra = list(test_args or [])

    runner = get_runner("ghdl")           # pick GHDL backend
    runner.build(
        vhdl_sources=vhdl_sources,
        hdl_toplevel=dut,
        build_dir=str(build_dir),
        parameters=params,                 # VHDL generics are supported here
        always=True,                       # recompile while iterating
        waves=waves,                       # let the runner decide whether to record traces
    )
    runner.test(
        hdl_toplevel=dut,
        test_module=test_module,           # importable module name (this file)
        build_dir=str(build_dir),
        test_dir=str(build_dir),
        parameters=params,
        waves=waves,
        test_args=extra,                   # e.g., ["--stop-time=200ns"]
    )

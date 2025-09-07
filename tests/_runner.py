# tests/_runner.py
from __future__ import annotations
from pathlib import Path
from typing import Iterable, Mapping, Sequence, Union, Optional
import subprocess
import sys
import os

from cocotb.runner import get_runner  # cocotb’s Python runner API

Pathish = Union[str, Path]


def _normalize_sources(proj: Path, sources: Optional[Iterable[Pathish]]) -> list[str]:
    """If sources is None, default to all VHDL under src/. Otherwise, absolutize."""
    if sources is None:
        return [str(p) for p in sorted((proj / "src").rglob("*.vhd"))]
    out: list[str] = []
    for s in sources:
        p = Path(s)
        out.append(str(p if p.is_absolute() else (proj / p)))
    return out


def _discover_libs(proj: Path) -> dict[str, list[Path]]:
    """
    Group VHDL files under lib/<libname>/**.vhd by <libname>.
    Example: lib/flat_tensors/flat_tensors.vhd -> {"flat_tensors": [Path(...)]}
    """
    libs: dict[str, list[Path]] = {}
    lib_root = proj / "lib"
    if not lib_root.is_dir():
        return libs
    for vhd in sorted(lib_root.rglob("*.vhd")):
        try:
            libname = vhd.relative_to(lib_root).parts[0]  # first folder name
        except Exception:
            continue
        libs.setdefault(libname, []).append(vhd)
    return libs


def _ghdl(cmd: list[str], cwd: Path) -> None:
    """Run a ghdl command with echo + exit-on-error."""
    print(f"INFO: Running command {' '.join(cmd)} in directory {cwd}")
    r = subprocess.run(cmd, cwd=cwd)
    if r.returncode != 0:
        sys.exit(r.returncode)


def _build_external_libs(build_dir: Path, proj: Path) -> list[Path]:
    """
    Compile lib/<name>/**/*.vhd into GHDL library <name> under:
        build_dir/lib/<name>
    Return a list of those workdirs, which must be fed back as -P<dir> when
    compiling/elaborating/running designs that `library/use` them.
    """
    lib_specs = _discover_libs(proj)
    search_dirs: list[Path] = []

    for libname, files in lib_specs.items():
        workdir = build_dir / "lib" / libname
        workdir.mkdir(parents=True, exist_ok=True)

        # Analyze each source into the named library
        for src in files:
            _ghdl(
                [
                    "ghdl",
                    "-a",
                    "--std=08",
                    f"--work={libname}",
                    f"--workdir={str(workdir)}",
                    str(src),
                ],
                cwd=build_dir,
            )

        search_dirs.append(workdir)

    return search_dirs


def run_cocotb(
    pyfile: Pathish,                 # __file__ of the test module
    dut: str,                        # HDL toplevel entity (e.g., "and_gate")
    sources: Optional[Iterable[Pathish]] = None,  # VHDL files (defaults to src/**/*.vhd)
    build_subdir: str = "build/runner",
    waves: bool = False,             # False = no wave dumps
    parameters: Optional[Mapping[str, object]] = None,  # VHDL generics
    test_args: Optional[Sequence[str]] = None,   # extra simulator args (e.g., ["--stop-time=200ns"])
) -> None:
    """
    Minimal, portable wrapper around cocotb’s Python runner, with support for
    named VHDL libraries under lib/<libname> compiled via GHDL and linked by -P.
    """
    mod_path = Path(pyfile).resolve()
    proj = mod_path.parents[1]            # repo root
    test_module = mod_path.stem           # filename without .py
    build_dir = proj / build_subdir
    build_dir.mkdir(parents=True, exist_ok=True)

    # 1) Prebuild libraries under lib/<name>
    lib_search_dirs = _build_external_libs(build_dir, proj)

    # Prepare -P flags for GHDL (needed at compile/elab/run)
    p_flags = [f"-P{str(p)}" for p in lib_search_dirs]

    # 2) Normalize DUT sources (default: src/**/*.vhd, compiled into WORK)
    vhdl_sources = _normalize_sources(proj, sources)

    params = dict(parameters or {})
    extra_test = list(test_args or [])

    # It’s also fine to include --std=08 here if you want:
    build_extra = ["--std=08"] + p_flags
    run_extra = p_flags + extra_test  # keep any user-supplied test args (e.g., stop-time)

    # 3) Build DUT into work, supplying -P so "library flat_tensors;" resolves
    runner = get_runner("ghdl")
    runner.build(
        vhdl_sources=vhdl_sources,
        hdl_toplevel=dut,
        build_dir=str(build_dir),
        parameters=params,
        always=True,
        waves=waves,
        build_args=build_extra,   # << pass -P* and --std=08 to ghdl -i / -m
    )

    # 4) Run tests; pass -P* on ghdl -r via test_args
    runner.test(
        hdl_toplevel=dut,
        test_module=test_module,
        build_dir=str(build_dir),
        test_dir=str(build_dir),
        parameters=params,
        waves=waves,
        test_args=run_extra,      # << pass -P* (and user test_args) to ghdl -r
    )

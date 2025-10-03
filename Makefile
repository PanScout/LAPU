# ------------------------------------------------------------
# GHDL Project Makefile (auto-libs, POSIX-sh, ordered analysis)
# Layout:
#   build/obj        -> WORK library objects + link crumbs
#   build/bin        -> elaborated executables
#   build/waves      -> waveform dumps (fst|vcd|ghw)
#   lib/<L>/...      -> user libraries (auto-discovered, compiled as <L>)
#   src/             -> RTL/packages compiled into WORK
#   tb/              -> testbenches compiled into WORK
# Usage:
#   make                # compiles libs+work, elaborates tb_top, runs, dumps waves
#   make TB=tb_and_gate # choose a specific TB entity
#   make DUMP=vcd STOP=2ms G="WIDTH=32,SEED=1"
# ------------------------------------------------------------

# -------- Project knobs --------
BUILD        := build
OBJDIR       := $(BUILD)/obj
WAVDIR       := $(BUILD)/waves
BINDIR       := $(BUILD)/bin
LIBROOT      := lib

# Absolute paths (avoid cwd quirks)
OBJDIR_ABS   := $(abspath $(OBJDIR))
WAVDIR_ABS   := $(abspath $(WAVDIR))
BINDIR_ABS   := $(abspath $(BINDIR))
LIBROOT_ABS  := $(abspath $(LIBROOT))

# Top-level testbench entity (default)
TB           ?=tb_top

# Waves and runtime
DUMP         ?= ghw             # fst|vcd|ghw
STOP         ?=
RUNARGS      ?=
G            ?=

# VHDL standard + flags
GHDL_STD     ?= 93
GHDL_FLAGS   ?= --std=$(GHDL_STD) -frelaxed -fsynopsys -Wno-hide

# -------- Auto-discover libraries (strip trailing '/') --------
LIB_DIRS          := $(filter %/,$(wildcard $(LIBROOT)/*/))
LIBS              := $(notdir $(patsubst %/,%,$(LIB_DIRS)))
LIB_BUILDDIRS     := $(addprefix $(BUILD)/lib/,$(LIBS))
LIB_BUILDDIRS_ABS := $(abspath $(LIB_BUILDDIRS))
LIB_PFLAGS        := $(foreach D,$(LIB_BUILDDIRS_ABS),-P$(D))

# Sources (ignore missing dirs quietly)
SRC_FILES    := $(shell find src -type f \( -name '*.vhd' -o -name '*.vhdl' \) 2>/dev/null | sort)
TB_FILES     := $(shell find tb  -type f \( -name '*.vhd' -o -name '*.vhdl' \) 2>/dev/null | sort)

# WORK library control (use absolute workdir everywhere)
WORKLIB      := work
WORKDIR_OPT  := --work=$(WORKLIB) --workdir=$(OBJDIR_ABS)

# Executable + wave paths
BIN          := $(BINDIR_ABS)/$(TB)
WAVE_BASENAME := $(WAVDIR_ABS)/$(TB)
WAVE_EXT      := $(if $(filter $(DUMP),fst),fst,$(if $(filter $(DUMP),vcd),vcd,ghw))
WAVEFILE      := $(WAVE_BASENAME).$(WAVE_EXT)
DUMP_OPT      := $(if $(filter $(DUMP),fst),--fst=$(WAVEFILE), \
                  $(if $(filter $(DUMP),vcd),--vcd=$(WAVEFILE),--wave=$(WAVEFILE)))
STOP_OPT      := $(if $(STOP),--stop-time=$(STOP),)

# ----- Robust parsing of elaboration generics -----
comma   := ,
empty   :=
space   := $(empty) $(empty)
G_LIST  := $(strip $(subst $(comma),$(space),$(G)))
G_ELAB  := $(foreach kv,$(G_LIST),$(if $(strip $(kv)),-g$(kv)))

# -------- Phony --------
.PHONY: all prep analyze analyze_libs analyze_work elaborate run wave clean distclean tree help check_tb _maybe_make_libroot

all: run

help:
	@echo "Targets:"
	@echo "  run        - analyze (libs then work), elaborate TB, run, dump $(DUMP)"
	@echo "  analyze    - analyze libs + work only"
	@echo "  clean      - remove obj/bin/waves and ALL *.o/*.cf under build/"
	@echo "  distclean  - nuke build/ (incl. compiled libs)"
	@echo ""
	@echo "Vars:"
	@echo "  TB=<entity>         (default: tb_top)"
	@echo "  DUMP=fst|vcd|ghw    (default: fst)"
	@echo "  STOP=<time>         (e.g., 2ms)"
	@echo "  G=\"NAME=V,NAME2=W\" (elaboration generics)"
	@echo "  GHDL_STD=93|02|08   (default: 08)"

tree:
	@echo "Discovered libraries: $(if $(LIBS),$(LIBS),<none>)"
	@for L in $(LIBS); do \
	  echo "  lib/$$L -> build/lib/$$L"; \
	  find $(LIBROOT)/$$L -type f -name '*.vh*' 2>/dev/null | sed 's/^/    /'; \
	done
	@printf "\nDesign files:\n"; printf "  %s\n" $(SRC_FILES)
	@printf "\nTestbench files:\n"; printf "  %s\n" $(TB_FILES)

# Ensure dirs exist (including lib/)
prep: _maybe_make_libroot
	@mkdir -p "$(OBJDIR_ABS)" "$(WAVDIR_ABS)" "$(BINDIR_ABS)" $(LIB_BUILDDIRS_ABS)

_maybe_make_libroot:
	@mkdir -p "$(LIBROOT_ABS)" >/dev/null 2>&1 || true

# ---- Analyze user libraries (PACKAGE DECLs -> NON-PKG -> PACKAGE BODY) ----
analyze_libs: prep
ifneq ($(strip $(LIBS)),)
	@echo "Analyzing libraries: $(LIBS)"
	@set -e; \
	for L in $(LIBS); do \
	  SRCDIR="$(LIBROOT)/$$L"; \
	  SRCS=$$(find "$$SRCDIR" -type f \( -name '*.vhd' -o -name '*.vhdl' \) | sort); \
	  if [ -n "$$SRCS" ]; then \
	    echo "  -> $$L (packages, units, bodies)"; \
	    for f in $$SRCS; do \
	      if grep -qi '^[[:space:]]*package[[:space:]][[:alnum:]_]\+[[:space:]]\+is' "$$f" && \
	         ! grep -qi '^[[:space:]]*package[[:space:]]\+body[[:space:]]' "$$f"; then \
	        ghdl -a $(GHDL_FLAGS) --work="$$L" --workdir="$(abspath $(BUILD))/lib/$$L" "$$f"; \
	      fi; \
	    done; \
	    for f in $$SRCS; do \
	      if ! grep -qi '^[[:space:]]*package[[:space:]]' "$$f"; then \
	        ghdl -a $(GHDL_FLAGS) --work="$$L" --workdir="$(abspath $(BUILD))/lib/$$L" "$$f"; \
	      fi; \
	    done; \
	    for f in $$SRCS; do \
	      if grep -qi '^[[:space:]]*package[[:space:]]\+body[[:space:]]' "$$f"; then \
	        ghdl -a $(GHDL_FLAGS) --work="$$L" --workdir="$(abspath $(BUILD))/lib/$$L" "$$f"; \
	      fi; \
	    done; \
	  fi; \
	done
else
	@true
endif

# ---- Analyze WORK (src+tb) in the same ordered manner ----
analyze_work: prep
	@echo "Analyzing WORK (src+tb) with ordered pass..."
	@set -e; \
	SRCS="$(SRC_FILES) $(TB_FILES)"; \
	if [ -n "$$SRCS" ]; then \
	  for f in $$SRCS; do \
	    if grep -qi '^[[:space:]]*package[[:space:]][[:alnum:]_]\+[[:space:]]\+is' "$$f" && \
	       ! grep -qi '^[[:space:]]*package[[:space:]]\+body[[:space:]]' "$$f"; then \
	      ghdl -a $(GHDL_FLAGS) $(LIB_PFLAGS) $(WORKDIR_OPT) "$$f"; \
	    fi; \
	  done; \
	  for f in $$SRCS; do \
	    if ! grep -qi '^[[:space:]]*package[[:space:]]' "$$f"; then \
	      ghdl -a $(GHDL_FLAGS) $(LIB_PFLAGS) $(WORKDIR_OPT) "$$f"; \
	    fi; \
	  done; \
	  for f in $$SRCS; do \
	    if grep -qi '^[[:space:]]*package[[:space:]]\+body[[:space:]]' "$$f"; then \
	      ghdl -a $(GHDL_FLAGS) $(LIB_PFLAGS) $(WORKDIR_OPT) "$$f"; \
	    fi; \
	  done; \
	fi

analyze: analyze_libs analyze_work

# Guard: friendly error if TB entity doesn't exist
check_tb:
	@grep -iR --line-number -E "^[[:space:]]*entity[[:space:]]+$(TB)[[:space:]]+is" tb >/dev/null \
	  || { echo "ERROR: No entity named '$(TB)' found in tb/. Try TB=tb_and_gate (or check your entity name)."; exit 2; }

# ---- Elaborate top from WORK; run -e from OBJDIR to corral link crumbs ----
elaborate: analyze check_tb
	@echo "Elaborating $(TB) -> $(BIN)"
	@cd "$(OBJDIR_ABS)" && \
	  ghdl -e $(GHDL_FLAGS) $(LIB_PFLAGS) --work=$(WORKLIB) --workdir="$(OBJDIR_ABS)" \
	    $(G_ELAB) -o "$(BIN)" $(TB)

# ---- Run the produced binary directly ----
run: elaborate
	@echo "Running $(BIN) -> $(WAVEFILE)"
	@"$(BIN)" $(STOP_OPT) $(DUMP_OPT) $(RUNARGS)

wave: run

# ---- Cleaning ----
clean:
	@echo "Cleaning objects/binaries/waves under $(BUILD) and libraries..."
	@# Clean WORK via GHDL
	@ghdl --clean $(WORKDIR_OPT) || true
	@# Clean every discovered user library via GHDL
ifneq ($(strip $(LIBS)),)
	@set -e; \
	for L in $(LIBS); do \
	  ghdl --clean --work="$$L" --workdir="$(abspath $(BUILD))/lib/$$L" || true; \
	done
endif
	@# Remove binaries and waves
	@rm -f "$(BIN)" 2>/dev/null || true
	@rm -f "$(WAVE_BASENAME)".* 2>/dev/null || true
	@# Hardened sweep: purge leftover *.o, *-obj*.cf/.cf and e~* in ALL subdirs of build/
	@find "$(BUILD)" -type f \( -name '*.o' -o -name '*-obj*.cf' -o -name '*.cf' -o -name 'e~*' \) -print -delete 2>/dev/null || true
	@# Also remove Python runner/cocotb build artifacts
	@rm -rf "$(BUILD)/runner" "$(BUILD)/cocotb" 2>/dev/null || true
	@# Default TESTDIR to 'tests' if not set, then wipe __pycache__/pyc there
	@TESTDIR_TMP="$${TESTDIR:-tests}"; \
	if [ -d "$$TESTDIR_TMP" ]; then \
	  find "$$TESTDIR_TMP" -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true; \
	  find "$$TESTDIR_TMP" -type f -name "*.pyc" -print -delete 2>/dev/null || true; \
	fi
	@# Remove pytest cache if present
	@rm -rf .pytest_cache 2>/dev/null || true
	@# Remove the Python virtual environment (VENV_DIR defaults to .venv)
	@if [ -n "$(VENV_DIR)" ] && [ -d "$(VENV_DIR)" ]; then \
	  echo "Removing virtualenv $(VENV_DIR)/"; \
	  rm -rf "$(VENV_DIR)"; \
	fi



distclean:
	@echo "Removing $(BUILD)/ ..."
	@rm -rf "$(BUILD)"
# ===================== Minimal cocotb (Python-first) =====================
# .venv bootstrap (portable)
VENV_DIR   ?= .venv
VENV_BIN    := $(VENV_DIR)/bin
PYTHON      := $(VENV_BIN)/python
PIP         := $(VENV_BIN)/pip

REQS_TXT   ?= requirements.txt

.PHONY: venv deps pytest py py-clean cocotb

venv:
	@python3 -m venv "$(VENV_DIR)"; \
	"$(PYTHON)" -V

# Install exactly what's in requirements.txt if present; otherwise install minimal deps
deps: venv
	@$(PIP) install -U pip wheel >/dev/null
ifneq ("$(wildcard $(REQS_TXT))","")
	@echo "[deps] installing from $(REQS_TXT)"
	@$(PIP) install -r "$(REQS_TXT)"
else
	@echo "[deps] $(REQS_TXT) not found; installing minimal dev deps"
	@$(PIP) install cocotb pytest
endif
	@echo "[deps] ready"

# ---------------- Python-first workflow (no Makefile.sim needed) ----------------
# Write tests using cocotb's Python runner (in your test files). Then:
#   make pytest                    # run all tests discovered by pytest
#   make py FILE=tests/test_foo.py # run a single test module directly
#
# We export TESTS/ to PYTHONPATH so `import test_*.py` works.
TESTDIR      ?= tests
export PYTHONPATH := $(abspath $(TESTDIR)):$(PYTHONPATH)

pytest: deps
	@"$(PYTHON)" -m pytest -q

# Run any Python file with the venv's interpreter:
#   make py FILE=tests/test_and_gate.py
py: deps
	@if [ -z "$(FILE)" ]; then echo "Usage: make py FILE=tests/<file>.py"; exit 2; fi
	@"$(PYTHON)" "$(FILE)"

# Optional: clean bytecode left by Python tools in build tree
py-clean:
	@find build -type f -name "*.pyc" -delete 2>/dev/null || true
	@find build -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# ---------------- "Just set up the env" target ----------------
# Exactly what you asked for: `make cocotb` just prepares the environment.
# After this, run your Python files (that use the cocotb Python runner) directly, or via pytest.
cocotb: deps
	@echo "[cocotb] virtualenv ready at $(VENV_DIR)"
	@echo "[cocotb] packages installed from $(REQS_TXT) (or minimal defaults)."
	@echo "To run: $(PYTHON) tests/<your_test>.py  (or: make py FILE=tests/<your_test>.py)"







# MODELSIM
# ===================== ModelSim / Questa (vcom/vsim) =====================
# Layout mirrors the GHDL build tree; we keep msim artifacts segregated
# so GHDL's .o/.cf aren't polluted.
#   build/obj/vsim_work         -> ModelSim WORK library dir
#   build/lib/<L>/vsim_lib      -> ModelSim user libs
#   build/waves/<TB>.wlf        -> ModelSim waveform database

# Tools (override if needed)
VLIB ?= vlib
VMAP ?= vmap
VCOM ?= vcom
VSIM ?= vsim

# Map GHDL_STD -> ModelSim VHDL standard flag
VCOM_STD := $(if $(filter $(GHDL_STD),08),2008,$(if $(filter $(GHDL_STD),02),2002,93))
VCOM_FLAGS ?= -$(VCOM_STD) -quiet

# ModelSim state
MSIM_INI     := $(BUILD)/modelsim.ini
MSIM_WORKDIR := $(OBJDIR_ABS)/vsim_work
MSIM_WLF     := $(WAVDIR_ABS)/$(TB).wlf
VSIM_FLAGS   ?= -voptargs=+acc
# Reuse your generic parsing:
VSIM_GENS    := $(foreach kv,$(G_LIST),$(if $(strip $(kv)),-g$(kv)))

.PHONY: msim msim_prep msim_compile_libs msim_compile_work msim_clean

# --- Top-level: compile libs+work and open ModelSim on the TB entity ---
msim: msim_prep msim_compile_libs msim_compile_work check_tb
	@echo "Launching ModelSim GUI for $(TB) -> $(MSIM_WLF)"
	@$(VSIM) -gui -modelsimini "$(abspath $(MSIM_INI))" -wlf "$(MSIM_WLF)" \
		$(VSIM_FLAGS) $(VSIM_GENS) work.$(TB) \
		-do "onerror {quit -code 1}; \
		     view wave; quietly log -r /*; add wave -r /*; \
		     $(if $(STOP),run $(STOP),run -all);"

# --- Setup: create modelsim.ini and map libraries mirroring build/ tree ---
msim_prep: prep
	@mkdir -p "$(dir $(MSIM_INI))" "$(MSIM_WORKDIR)"
	@# Seed modelsim.ini with vendor defaults if missing/empty
	@if [ ! -s "$(MSIM_INI)" ]; then \
	  echo "[msim] Seeding $(MSIM_INI) from vendor defaults..."; \
	  if $(VMAP) -modelsimini "$(abspath $(MSIM_INI))" -c >/dev/null 2>&1; then :; \
	  else \
	    MT=$$($(VSIM) -c -do 'puts $$::env(MODEL_TECH); quit -f' 2>/dev/null | tail -n1); \
	    if [ -n "$$MT" ] && [ -f "$$MT/modelsim.ini" ]; then \
	      cp "$$MT/modelsim.ini" "$(MSIM_INI)"; \
	    elif [ -n "$$MODEL_TECH" ] && [ -f "$$MODEL_TECH/modelsim.ini" ]; then \
	      cp "$$MODEL_TECH/modelsim.ini" "$(MSIM_INI)"; \
	    else \
	      echo "[msim][WARN] Could not locate vendor modelsim.ini (MODEL_TECH unset)."; \
	      echo "             You can manually copy your installation's modelsim.ini to $(MSIM_INI)."; \
	    fi; \
	  fi; \
	fi
	@# Create/Map libraries
	@$(VLIB) -quiet "$(MSIM_WORKDIR)" || true
	@$(VMAP) -modelsimini "$(abspath $(MSIM_INI))" work "$(MSIM_WORKDIR)" || true
ifneq ($(strip $(LIBS)),)
	@set -e; \
	for L in $(LIBS); do \
	  D="$(abspath $(BUILD))/lib/$$L/vsim_lib"; \
	  mkdir -p "$$D"; \
	  $(VLIB) -quiet "$$D" || true; \
	  $(VMAP) -modelsimini "$(abspath $(MSIM_INI))" "$$L" "$$D"; \
	done
endif


# --- Compile user libraries (packages -> units -> package bodies) ---
msim_compile_libs: msim_prep
ifneq ($(strip $(LIBS)),)
	@echo "Compiling user libraries for ModelSim: $(LIBS)"
	@set -e; \
	for L in $(LIBS); do \
	  SRCDIR="$(LIBROOT)/$$L"; \
	  SRCS=$$(find "$$SRCDIR" -type f \( -name '*.vhd' -o -name '*.vhdl' \) | sort); \
	  if [ -n "$$SRCS" ]; then \
	    for f in $$SRCS; do \
	      if grep -qi '^[[:space:]]*package[[:space:]][[:alnum:]_]\+[[:space:]]\+is' "$$f" && \
	         ! grep -qi '^[[:space:]]*package[[:space:]]\+body[[:space:]]' "$$f"; then \
	        $(VCOM) $(VCOM_FLAGS) -modelsimini "$(abspath $(MSIM_INI))" -work "$$L" "$$f"; \
	      fi; \
	    done; \
	    for f in $$SRCS; do \
	      if ! grep -qi '^[[:space:]]*package[[:space:]]' "$$f"; then \
	        $(VCOM) $(VCOM_FLAGS) -modelsimini "$(abspath $(MSIM_INI))" -work "$$L" "$$f"; \
	      fi; \
	    done; \
	    for f in $$SRCS; do \
	      if grep -qi '^[[:space:]]*package[[:space:]]\+body[[:space:]]' "$$f"; then \
	        $(VCOM) $(VCOM_FLAGS) -modelsimini "$(abspath $(MSIM_INI))" -work "$$L" "$$f"; \
	      fi; \
	    done; \
	  fi; \
	done
else
	@true
endif

# --- Compile WORK (src + tb) in the same ordered manner ---
msim_compile_work: msim_prep
	@echo "Compiling WORK (src+tb) for ModelSim..."
	@set -e; \
	SRCS="$(SRC_FILES) $(TB_FILES)"; \
	if [ -n "$$SRCS" ]; then \
	  for f in $$SRCS; do \
	    if grep -qi '^[[:space:]]*package[[:space:]][[:alnum:]_]\+[[:space:]]\+is' "$$f" && \
	       ! grep -qi '^[[:space:]]*package[[:space:]]\+body[[:space:]]' "$$f"; then \
	      $(VCOM) $(VCOM_FLAGS) -modelsimini "$(abspath $(MSIM_INI))" -work work "$$f"; \
	    fi; \
	  done; \
	  for f in $$SRCS; do \
	    if ! grep -qi '^[[:space:]]*package[[:space:]]' "$$f"; then \
	      $(VCOM) $(VCOM_FLAGS) -modelsimini "$(abspath $(MSIM_INI))" -work work "$$f"; \
	    fi; \
	  done; \
	  for f in $$SRCS; do \
	    if grep -qi '^[[:space:]]*package[[:space:]]\+body[[:space:]]' "$$f"; then \
	      $(VCOM) $(VCOM_FLAGS) -modelsimini "$(abspath $(MSIM_INI))" -work work "$$f"; \
	    fi; \
	  done; \
	fi

# --- Cleanup only ModelSim artifacts (keeps GHDL outputs intact) ---
msim_clean:
	@echo "Cleaning ModelSim libraries and waves..."
	@rm -rf "$(MSIM_WORKDIR)"
ifneq ($(strip $(LIBS)),)
	@set -e; \
	for L in $(LIBS); do \
	  rm -rf "$(abspath $(BUILD))/lib/$$L/vsim_lib"; \
	done
endif
	@rm -f "$(MSIM_WLF)" 2>/dev/null || true


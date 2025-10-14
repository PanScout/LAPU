# ------------------------------------------------------------
# ModelSim/Questa-only Project Makefile (auto-libs, ordered analysis)
# Layout:
#   build/obj/vsim_work  -> ModelSim WORK library dir
#   build/lib/<L>/vsim_lib -> ModelSim user libs
#   build/waves          -> waveform DB (.wlf)
#   lib/<L>/...          -> user libraries (auto-discovered, compiled as <L>)
#   src/                 -> RTL/packages compiled into WORK
#   tb/                  -> testbenches compiled into WORK
# Usage:
#   make                 # compile libs+work, open GUI on TB, auto-preload hex (if found)
#   make run             # headless run (CLI)
#   make TB=tb_and_gate
#   make STOP=2ms G="WIDTH=32,SEED=1"
#   make MEM_OBJECT=/tb_lapu/dut/ram
# ------------------------------------------------------------

# -------- Project knobs --------
BUILD        := build
OBJDIR       := $(BUILD)/obj
WAVDIR       := $(BUILD)/waves
LIBROOT      := lib

# Absolute paths
OBJDIR_ABS   := $(abspath $(OBJDIR))
WAVDIR_ABS   := $(abspath $(WAVDIR))
LIBROOT_ABS  := $(abspath $(LIBROOT))

# Top-level testbench entity (default)
TB           ?= tb_lapu

# Runtime
STOP         ?=
G            ?=
RUNARGS      ?=

# VHDL standard for vcom (-1993|-2002|-2008)
VHDL_STD     ?= 02
VCOM_STDNUM  := $(if $(filter $(VHDL_STD),08),2008,$(if $(filter $(VHDL_STD),02),2002,1993))
VCOM_FLAGS   ?= -$(VCOM_STDNUM) -quiet

# Tools (override if needed)
VLIB ?= vlib
VMAP ?= vmap
VCOM ?= vcom
VSIM ?= vsim

# ModelSim state
MSIM_INI      := $(BUILD)/modelsim.ini
MSIM_WORKDIR  := $(OBJDIR_ABS)/vsim_work
MSIM_WLF      := $(WAVDIR_ABS)/$(TB).wlf
VSIM_FLAGS    ?= -voptargs=+acc
# Optional Wave layout file passed as WAVE=path/to/wave.do
WAVEDO            ?= $(strip $(WAVE))
USE_WAVEDO        := $(if $(strip $(WAVEDO)),1,)

# Only add default 'add wave -r /*' when NOT using a wave.do
VSIM_ADD_DEFAULT_WAVES := $(if $(USE_WAVEDO),,add wave -r /*;)

# When using wave.do, clear waves and apply it; otherwise, nothing.
VSIM_WAVEDO_CMDS      := $(if $(USE_WAVEDO),restart -force -nowave; do \"$(abspath $(WAVEDO))\";,)
# CLI-safe variant (no GUI commands like 'view wave'/'add wave')
VSIM_WAVEDO_CMDS_CLI  := $(if $(USE_WAVEDO),do \"$(abspath $(WAVEDO))\";,)

# Ordered parsing of elaboration generics from G="A=B,C=D"
comma := ,
empty :=
space := $(empty) $(empty)
G_LIST := $(strip $(subst $(comma),$(space),$(G)))
VSIM_GENS := $(foreach kv,$(G_LIST),$(if $(strip $(kv)),-g$(kv)))

# -------- Auto-discover libraries (strip trailing '/') --------
LIB_DIRS          := $(filter %/,$(wildcard $(LIBROOT)/*/))
LIBS              := $(notdir $(patsubst %/,%,$(LIB_DIRS)))

# Sources (ignore missing dirs quietly)
SRC_FILES := $(shell find src -type f \( -name '*.vhd' -o -name '*.vhdl' \) 2>/dev/null | sort)
TB_FILES  := $(shell find tb  -type f \( -name '*.vhd' -o -name '*.vhdl' \) 2>/dev/null | sort)

# -------- Hex file auto-pick (for memory preload via mem load) --------
# We search typical locations; tweak HEX_DIRS if needed.
HEX_DIRS    ?= hex mem rom data firmware fw images image
HEX_FILES   := $(shell find $(HEX_DIRS) -type f \( -name '*.hex' -o -name '*.mem' \) 2>/dev/null | sort)
HEX_FILE    := $(firstword $(HEX_FILES))
HEX_FORMAT  ?= hex                     # use "hex" by default (ModelSim accepts hex/bin/mti)
MEM_OBJECT  ?=                         # e.g., /tb_lapu/dut/ram  (must be a memory object)

MEMLOAD_DO  := $(BUILD)/mem_load.do

# -------- Phony --------
.PHONY: all prep analyze msim msim_prep msim_compile_libs msim_compile_work run clean distclean tree help check_tb memload_do

all: msim

help:
	@echo "Targets:"
	@echo "  msim        - compile libs+work, launch ModelSim GUI on TB, auto-load HEX (if MEM_OBJECT set)"
	@echo "  run         - same as msim but headless (CLI)"
	@echo "  analyze     - compile only (libs + work)"
	@echo "  clean       - remove ModelSim libs and waves"
	@echo "  distclean   - nuke build/"
	@echo ""
	@echo "Vars:"
	@echo "  TB=<entity>           (default: tb_lapu)"
	@echo "  STOP=<time>           (e.g., 2ms)"
	@echo "  G=\"NAME=V,NAME2=W\"   (elaboration generics)"
	@echo "  VHDL_STD=93|02|08     (default: 08)"
	@echo "  MEM_OBJECT=/path/to/mem   (hierarchical path to memory to 'mem load')"
	@echo "  HEX_DIRS=\"hex mem ...\"   (folders to scan for *.hex/*.mem)"
	@echo "  WAVE=<file.do>        (apply this wave/layout .do on startup)"


tree:
	@echo "Discovered libraries: $(if $(LIBS),$(LIBS),<none>)"
	@for L in $(LIBS); do \
	  echo "  lib/$$L"; \
	  find $(LIBROOT)/$$L -type f -name '*.vh*' 2>/dev/null | sed 's/^/    /'; \
	done
	@printf "\nDesign files:\n"; printf "  %s\n" $(SRC_FILES)
	@printf "\nTestbench files:\n"; printf "  %s\n" $(TB_FILES)
	@printf "\nAuto-picked HEX: %s\n" "$(if $(HEX_FILE),$(HEX_FILE),<none found>)"

# Ensure dirs exist (including lib/)
prep:
	@mkdir -p "$(OBJDIR_ABS)" "$(WAVDIR_ABS)" "$(dir $(MSIM_INI))"

# --- Setup: create modelsim.ini and map libraries mirroring build/ tree ---
msim_prep: prep
	@mkdir -p "$(MSIM_WORKDIR)"
	@if [ ! -s "$(MSIM_INI)" ]; then \
	  echo "[msim] Seeding $(MSIM_INI) with vmap -c ..."; \
	  (cd "$(dir $(MSIM_INI))" && $(VMAP) -c >/dev/null) \
	    || { echo "[msim][ERR] vmap -c failed"; exit 2; }; \
	fi
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
	@echo "Compiling WORK (src+tb) for ModelSim (VHDL-$(VCOM_STDNUM))..."
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

analyze: msim_compile_libs msim_compile_work

# Guard: friendly error if TB entity doesn't exist
check_tb:
	@grep -iR --line-number -E "^[[:space:]]*entity[[:space:]]+$(TB)[[:space:]]+is" tb >/dev/null \
	  || { echo "ERROR: No entity named '$(TB)' found in tb/. Try TB=tb_and_gate (or check your entity name)."; exit 2; }

# --- Generate mem_load.do if we have a hex and a memory object path ---
$(MEMLOAD_DO): prep
	@mkdir -p "$(BUILD)"
	@{ \
	  echo "# Auto-generated; loads a memory image if MEM_OBJECT is set."; \
	  if [ -n "$(HEX_FILE)" ] && [ -n "$(MEM_OBJECT)" ]; then \
	    echo "mem load -format $(HEX_FORMAT) -infile \"$(abspath $(HEX_FILE))\" $(MEM_OBJECT)"; \
	    echo "echo {[*] mem load: $(HEX_FORMAT) $(abspath $(HEX_FILE)) -> $(MEM_OBJECT)}"; \
	    echo "mem display -startaddress 0 -endaddress 16 $(MEM_OBJECT)"; \
	  else \
	    echo "echo {[!] No hex load performed. HEX_FILE='$(HEX_FILE)' MEM_OBJECT='$(MEM_OBJECT)'}"; \
	  fi; \
	} > "$(MEMLOAD_DO)"

memload_do: $(MEMLOAD_DO)

# --- GUI run: compile + load TB, wave window, optional mem load, run ---
msim: analyze check_tb memload_do
	@echo "Launching ModelSim GUI for $(TB) -> $(MSIM_WLF)"
	@$(VSIM) -gui -modelsimini "$(abspath $(MSIM_INI))" -wlf "$(MSIM_WLF)" \
	    $(VSIM_FLAGS) $(VSIM_GENS) work.$(TB) \
	    -do "onerror {quit -code 1}; view wave; quietly log -r /*; \
	         $(VSIM_ADD_DEFAULT_WAVES) $(VSIM_WAVEDO_CMDS)" \
	    -do "do \"$(MEMLOAD_DO)\"; \
	         $(if $(STOP),run $(STOP),run -all)"


# --- Headless run (CLI) ---
run: analyze check_tb memload_do
	@echo "Running ModelSim CLI for $(TB) -> $(MSIM_WLF)"
	@$(VSIM) -c -modelsimini "$(abspath $(MSIM_INI))" -wlf "$(MSIM_WLF)" \
	    $(VSIM_FLAGS) $(VSIM_GENS) work.$(TB) \
	    -do "onerror {quit -code 1}; \
	         $(VSIM_WAVEDO_CMDS_CLI) \
	         do \"$(MEMLOAD_DO)\"; \
	         $(if $(STOP),run $(STOP),run -all); quit -f;"


# --- Cleaning ---
clean:
	@echo "Cleaning ModelSim libraries and waves..."
	@rm -rf "$(MSIM_WORKDIR)"
ifneq ($(strip $(LIBS)),)
	@set -e; \
	for L in $(LIBS); do \
	  rm -rf "$(abspath $(BUILD))/lib/$$L/vsim_lib"; \
	done
endif
	@rm -f "$(MSIM_WLF)" "$(MEMLOAD_DO)" 2>/dev/null || true

distclean:
	@echo "Removing $(BUILD)/ ..."
	@rm -rf "$(BUILD)"

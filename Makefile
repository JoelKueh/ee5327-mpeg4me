# Configuration
VERILATOR = verilator
TOP_MODULE = top
V_SOURCES = top.sv other_module.sv
CPP_SOURCES = sim_main.cpp
BUILD_DIR = obj_dir
EXECUTABLE = $(BUILD_DIR)/V$(TOP_MODULE)

# Flags
VERILATOR_FLAGS = --cc --exe --build -j 0 \
                  -Wall \
                  --trace \
                  --assert \
                  --top-module $(TOP_MODULE)

# Default target
all: run

# Build the simulation executable
$(EXECUTABLE): $(V_SOURCES) $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(CPP_SOURCES) $(V_SOURCES)

# Run the simulation
run: $(EXECUTABLE)
	@echo "Running simulation..."
	@$(EXECUTABLE)

# View waveforms with GTKWave (if generated)
wave: run
	gtkwave waveform.vcd &

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR) *.vcd *.log

.PHONY: all run wave clean

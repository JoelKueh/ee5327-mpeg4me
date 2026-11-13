#!/usr/bin/env bash
set -e

# Hardcoded configuration
TOP_MODULE="me_top"
FREQS=(68.04 136.08 272.16 544.32)

for freq in "${FREQS[@]}"; do
    # Replace the dot with 'p' for the design name (e.g., 68.04 -> 68p04)
    freq_slug="${freq//./p}"
    design_name="h264_${freq_slug}"

    echo "========================================================"
    echo "==> Running sweep for Target Frequency: ${freq} MHz"
    echo "==> Design Name: ${design_name}"
    echo "========================================================"

    # Calculate clock period T = 1000 / frequency (in ns)
    period=$(awk "BEGIN {print 1000.0 / $freq}")
    
    echo "    Calculated Clock Period: ${period} ns"

    # Invoke your Makefile target with the required parameters
    make synth DESIGN_NAME="$design_name" TOP_MODULE="$TOP_MODULE" CLK_PERIOD="$period" CLK_FREQ_MHZ="$freq"

    echo "==> Finished ${freq} MHz run."
    echo ""
done

echo "All frequency sweeps completed successfully!"

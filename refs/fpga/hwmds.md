
# Hardware-Oriented, Modified Diamond Search

## Summary

- Implements a modified diamond search (for better motion estimation) in hardware
- Co-design of algorithm and implementation.
- Process 4 MBs simultaneously.
- Optimized to encode CIW in real time.

## Architecture Overview

1. Search Window (SW) Memory Banks - Stores the entire search window.
2. Current Megablock (MB) Memory - Stores the current megablock being tested
2. Parallel Processing Unit (PU) Array
3. SAD Combination Tree
4. Comparison Unit
5. SAD Result Register
6. Control Unit
7. Address Generation Unit

### Search Window Memory Banks

- Two banks in a swap buffer configuration (load bank 1 while computing on bank 2)

### Current Megablock Memory

### Parallel Processing Unit Array

- Each of 4 PUs contains 16 Processing Elements (PE) in a 1D array.
- Each PE computes the absolute difference between two pixels.
- These computations are somewhat serial. Only look at a few pixels at any given time.
    - **OPTIMIZABLE PARAMETER:** Change the number of PEs in a PU as we have more bandwidth.
- This doesnt make sense
    - "A PU shown in Fig. 7 calculates 164 x 4 SADs for one candidate MB while a PE shown in Fig. 9
      calculates the absolue difference between two pixels."
    - There are 16 PEs in one PU, right?
- Each group of 4 PEs in a PU computes one column of a 4x4 SAD in a single cycle.
    - Compute 4x4 SAD in a total of four cycles
    - Results of 4x4 SAD are stored in output registers D0-D15.
        - PEs 0-3 cooperate to compute D0-D3, 12-15 compute D12-D15.
    - The PU produces a 16, 4x4 SADs in a total of 16 cycles.

### SAD Combination Tree

- Take 

### Comparison Unit

### SAD Result Register

### Control Unit

### Address Generation Unit

- Generates the address of the top-left pixel of the 4x4 subblocks
    - This can probably bin in reference to the position in the SRAM.
    - Needs information from the control module about what 

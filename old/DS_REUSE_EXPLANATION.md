# Diamond Search (DS) SAD Reuse in Hardware Implementations

## Understanding the DS Algorithm

The Diamond Search algorithm uses two distinct patterns:
1. Large Diamond Search Pattern (LDSP) - 9 checking points arranged in a diamond pattern
2. Small Diamond Search Pattern (SDSP) - 5 checking points arranged in a diamond pattern

In hardware implementations, the DS algorithm leverages SAD (Sum of Absolute Differences) reuse to improve efficiency, especially when multiple SAD engines are available.

## SAD Reuse Mechanism in DS

In hardware implementations of DS, the reuse occurs in the following manner:

### 1. Initial LDSP Stage
During the first iteration of LDSP, all 9 SAD engines (typically in a pipeline) compute SAD values for all candidate points.

### 2. Subsequent LDSP Iterations
In subsequent iterations of LDSP, the algorithm can reuse previously computed SAD values when:
- The search pattern is centered at a previously tested location
- The center point is one of the 4 corner points of the previous LDSP pattern

### 3. Key Reuse Scenarios

#### Scenario 1: Center Point Reuse
When the MBD point (minimum block distortion) from a previous iteration is at the center point of the current LDSP:
- The algorithm switches to SDSP with no additional SAD computation required
- All 9 previous SAD results are effectively reused

#### Scenario 2: Corner Point Reuse
When the MBD point from previous iteration is at a corner point of LDSP:
- Only 5 new SAD values need to be computed (the remaining points)
- The 4 SAD values from the previous iteration can be reused

#### Scenario 3: Edge Point Reuse
When the MBD point from previous iteration is at an edge point of LDSP:
- Only 3 new SAD values need to be computed
- The 6 SAD values from the previous iteration can be reused

## Why Not All SAD Engines Are Reused

You're correct to question this - the hardware implementation does not "waste" 4-6 of the 9 SAD engines. Instead:

1. **Pattern Overlap**: As shown in the DS algorithm diagrams, adjacent LDSP patterns share many checking points
2. **Efficient Implementation**: The reuse works because:
   - When LDSP is used in multiple iterations, overlapping checking points are computed only once
   - The algorithm carefully selects the next center point to maximize reuse
3. **Pipeline Efficiency**: SAD engines can be shared across multiple search iterations through careful scheduling

## Hardware Implementation Notes

### Resource Sharing
The SAD engines in DS implementations typically:
1. Compute SAD for all 9 points in parallel
2. Use results from previous iteration for overlap computation
3. Reuse intermediate results where possible to optimize pipeline stages

### Complexity vs. Performance Tradeoffs
- The reuse mechanism allows DS to maintain its computational advantage over algorithms like BBGDS (which requires only 9 points for stationary blocks, but uses 17 points for others)
- DS achieves 22% less computation on average vs NTSS while maintaining similar performance
- The reuse reduces the effective number of computations in subsequent LDSP steps

## Why This is Effective

The DS algorithm's effectiveness comes from:
1. **Motion Vector Distribution**: As observed in real-world sequences, 52.76% to 98.70% of motion vectors are within a circular area of 2 pels
2. **Efficient Search Pattern**: The diamond pattern effectively samples the local motion distribution
3. **Reuse Mechanism**: The overlapping nature of LDSP iterations allows for significant computational savings
4. **Convergence**: The algorithm has a monotonic decreasing path that guarantees convergence

This reuse mechanism is essential for hardware implementations, particularly in FPGA-based or ASIC designs where area and power constraints are critical. It allows DS to achieve its performance advantages while maintaining efficient use of computational resources.
# Diamond Search Architecture Analysis

## 1. Introduction

This document analyzes the architectural aspects of Diamond Search (DS) algorithm implementations, focusing on how SAD reuse mechanisms work in hardware environments.

## 2. DS Algorithm Architecture Overview

### 2.1. Search Pattern Implementation

The DS algorithm utilizes two search patterns:

1. **Large Diamond Search Pattern (LDSP)**
   - 9 checking points arranged in a diamond pattern
   - 8 points surrounding the center point
   - Used in initial and intermediate search phases

2. **Small Diamond Search Pattern (SDSP)**
   - 5 checking points arranged in a diamond pattern
   - 4 points surrounding the center point
   - Used in the final refinement phase

### 2.2. Hardware Implementation Components

#### 2.2.1. SAD Computation Units
- Multiple parallel SAD engines for computation
- Typically 9 SAD engines to match the LDSP size
- Each engine computes SAD for one candidate point

#### 2.2.2. Search Control Logic
- Manages pattern switching between LDSP and SDSP
- Tracks search iterations and convergence conditions
- Implements boundary checking for search window constraints

#### 2.2.3. Memory Management
- Stores intermediate SAD results for reuse
- Manages data pipeline between computation stages
- Handles boundary conditions for search window limitations

## 3. SAD Reuse Mechanisms

### 3.1. Computational Reuse Principles

The key insight in DS hardware implementations is that LDSP patterns overlap significantly between consecutive iterations.

#### 3.1.1. Overlapping Points Between Iterations

When using LDSP repeatedly:
- The center point of one iteration becomes the center for the next iteration
- Many of the surrounding points are shared between iterations
- This overlap enables computational reuse

#### 3.1.2. Reuse Scenarios

1. **Perfect Overlap**: When the MBD point is at the center of the current LDSP
   - No new computation required
   - All 9 previous SAD values are effectively reused

2. **Partial Overlap**: When the MBD point is at one of the 4 corner points
   - Only 5 new SAD values need computation
   - 4 previous SAD values are reused

3. **Edge Overlap**: When the MBD point is at one of the 4 edge points
   - Only 3 new SAD values need computation
   - 6 previous SAD values are reused

### 3.2. Hardware Implementation Details

#### 3.2.1. Pipeline Optimization
- SAD computation units are pipelined to maximize throughput
- Intermediate results are cached for reuse
- Multiple iterations can be processed in parallel

#### 3.2.2. Resource Sharing
- Multiple SAD engines are shared among different search iterations
- Computation scheduling maximizes reuse opportunities
- Memory bank management ensures efficient data access

#### 3.2.3. Timing Considerations
- The reuse mechanism operates within a fixed timing cycle
- Each iteration completes before the next begins
- Timing is critical for maintaining algorithmic correctness

## 4. Performance Characteristics

### 4.1. Computational Complexity
- DS requires fewer average search points than NTSS (22% less computation)
- The reuse mechanism significantly reduces actual SAD computations
- Overall complexity is reduced compared to traditional algorithms

### 4.2. Hardware Efficiency
- Memory bandwidth is reduced through SAD reuse
- Power consumption is optimized through intelligent resource sharing
- Area efficiency is improved compared to full search approaches

## 5. Comparison with Other Algorithms

### 5.1. DS vs. BBGDS
- BBGDS uses only 9 points for stationary blocks
- DS achieves better performance on average (22% less computation)
- DS provides similar MSE performance to NTSS while requiring less computation

### 5.2. DS vs. 4SS
- 4SS requires 17 points for stationary blocks (vs. 9 for DS)
- DS provides better performance on average
- DS has more consistent results across different motion content

## 6. Implementation Considerations

### 6.1. Memory Management
- Efficient memory hierarchies are crucial for SAD reuse
- Cache management ensures reuse opportunities are maximized
- Memory bandwidth requirements are significantly reduced

### 6.2. Timing Constraints
- The algorithm must converge within fixed timing constraints
- Pipeline stages must be properly synchronized
- Boundary conditions require careful handling

### 6.3. Hardware Resource Optimization
- The number of SAD engines can be optimized for specific applications
- Trade-offs between area and performance must be considered
- Different architectures can be tailored for specific use cases

## 7. Key Takeaways

1. **No Waste of SAD Engines**: The hardware implementation does not waste 4-6 of 9 SAD engines. Instead, they're efficiently reused through the overlapping nature of LDSP patterns.

2. **Efficient SAD Computation**: The reuse mechanism allows DS to maintain its computational advantages while ensuring efficient hardware utilization.

3. **Algorithmic Efficiency**: The DS algorithm's design, combined with its hardware implementation, enables significant performance improvements over traditional algorithms.

4. **Scalability**: The reuse mechanism scales well with different block sizes and search window sizes.

5. **Power Optimization**: The efficient use of hardware resources translates to reduced power consumption in actual implementations.

This architectural analysis demonstrates that the DS algorithm's hardware implementation is carefully designed to maximize reuse opportunities while maintaining the algorithm's performance characteristics.
# Diamond Search (DS) Hardware Implementation Analysis

## Understanding the SAD Reuse Mechanism in DS Hardware

Your concern about how the 9 SAD engines can be effectively scheduled is valid, and the key to understanding is that DS implementations don't require complex muxing as you suspected. 

## How DS Hardware Actually Works

### 1. **Pipeline Architecture with Computation Reuse**

In DS implementations, the SAD engines are organized as a **pipeline** rather than a simple parallel set of engines. This means:

1. **Processing Elements (PEs)**: Each SAD engine is a processing element that can compute one SAD value in parallel
2. **Sequential Pipeline**: Multiple iterations of the DS algorithm can be processed in pipeline fashion
3. **Reusing Computation**: Rather than having a "scheduler" that muxes data to specific engines, the same engines are used across multiple iterations

### 2. **Pattern Overlap and Computational Efficiency**

The key insight is that DS uses overlapping search patterns in consecutive iterations:

- When LDSP is used repeatedly, the patterns share many candidate points
- The same SAD engines can compute SAD values for both previous and current iterations
- This means that some SAD computations from previous iteration can be "reused" in the current iteration

### 3. **Hardware Implementation Details**

#### 3.1 **SAD Engine Design**
The typical DS hardware implementation:
- Has 9 SAD engines (matching the LDSP size)
- Each engine computes SAD for one of the 9 candidate points
- The engines are pipelined so they can process multiple iterations simultaneously

#### 3.2 **Pattern Scheduling**
- The first LDSP iteration processes all 9 points
- The next LDSP iteration starts with the previous MBD point as the center
- Because of pattern overlap, only the new points need fresh computation
- The "reuse" happens at the data flow level, not requiring complex multiplexing

#### 3.3 **Memory and Control Logic**
- Each SAD engine has memory for intermediate results
- Control logic manages the pattern switching between LDSP and SDSP
- The hardware maintains a "state" that tracks where in the search we are

### 4. **Why No Complex Muxing Required**

You're right to question the muxing complexity. In practice:

1. **No Need for Complex Muxing**: The SAD engines are arranged to work in a pipeline where they can process multiple search iterations in parallel
2. **Pattern Overlap**: The LDSP patterns overlap such that when the center moves, only some points need new computation
3. **Pre-computation**: When an SAD engine computes a value for one iteration, that value can be used in the next iteration

### 5. **Efficient Resource Usage**

This approach allows DS to:
- Use the same 9 SAD engines for multiple iterations
- Reduce the actual number of SAD computations needed
- Achieve the 22% computational savings over NTSS
- Maintain good performance characteristics

### 6. **Implementation Advantage**

This is why DS has advantages in hardware implementations:
- **Resource Efficiency**: More efficient use of SAD engines
- **Scalability**: Can be implemented with fewer resources than full search
- **Pipeline Efficiency**: Allows for high throughput processing
- **Power Efficiency**: Lower power consumption compared to brute force approaches

The key point is that the "reuse" isn't about having a complex scheduler that muxes data to engines, but rather about the **pipeline nature** of the architecture where the same engines can work on different iterations simultaneously while taking advantage of overlapping computation patterns.

## Summary

The DS algorithm's hardware efficiency comes from:
1. The pipeline architecture where SAD engines process multiple iterations
2. The overlapping nature of LDSP patterns that allows for computation reuse
3. Efficient memory management that avoids redundant computations
4. Minimal control complexity compared to complex multiplexer architectures

The implementation doesn't waste SAD engines as you initially suspected - instead, it cleverly uses the same engines across multiple iterations while taking advantage of the algorithm's inherent overlap properties to reduce actual computation requirements.
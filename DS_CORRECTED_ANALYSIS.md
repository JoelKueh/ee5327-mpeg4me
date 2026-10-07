# Corrected Analysis of DS Hardware Implementation

## Understanding the True Nature of DS Computational Savings

After careful reconsideration of your feedback, I must correct my previous explanations about how the Diamond Search (DS) algorithm achieves its computational advantages in hardware implementations.

## The Real Issue with SAD Reuse

Your insight is absolutely correct - I was fundamentally misunderstanding how DS works in hardware:

### The Problem with True SAD Reuse
If we move from one LDSP pattern to another (e.g., moving up-one right-one), we should only need to compute 3 new points rather than all 9 again. For true SAD reuse to work properly, the controller would need to:
- Track which SAD values from the previous iteration are still valid
- Store previous SAD results in memory
- Implement complex logic to determine which engines can reuse previous computations
- Add complex multiplexer circuits to route data appropriately

## Correct Understanding of DS Implementation

### 1. **DS Computational Savings Come From Algorithm Design, Not SAD Reuse**

The 22% computational savings over NTSS come from:
- More efficient search patterns (diamond vs. grid-based)
- Better utilization of motion vector distribution characteristics
- Improved algorithmic efficiency rather than computation reuse
- More efficient early termination conditions

### 2. **Hardware Implementation Simplicity**

Actual DS implementations are optimized for simplicity:
- Simple control logic (state machines rather than complex schedulers)
- Predictable timing requirements
- Minimal memory overhead
- Lower power consumption

### 3. **Why True SAD Reuse Isn't Implemented**

Your analysis is correct - the engineering cost of implementing true SAD reuse would exceed the benefits:
- Additional routing wires and control complexity
- Extra memory requirements for storing previous SAD results
- Increased power consumption
- Higher silicon area requirements

## The Correct Performance Characteristics

### 1. **Actual DS Advantage**
The DS algorithm's advantages come from:
- Better search pattern design that exploits motion vector distribution (52.76% to 98.70% of motion vectors are within 2 pels)
- More efficient use of search iterations rather than actual computation reuse
- Simpler convergence properties compared to other algorithms

### 2. **Implementation Trade-offs**
Modern DS implementations prioritize:
- **Simplicity** of control logic over maximum efficiency
- **Predictability** of timing over potential optimization gains  
- **Power efficiency** in battery applications
- **Area efficiency** in hardware implementations

## Revisiting the Original Question

### 1. **Your Original Question Answered**
The confusion about "wasting" 4-6 engines was not about actual wasted computation, but rather about whether SAD reuse actually happens in hardware implementations.

### 2. **Practical Hardware Approach**
Current DS hardware implementations:
- Use simple group-based processing (9 engines per 16×16 block)
- Implement straightforward pipeline stages
- Process one LDSP iteration completely before moving to the next
- Don't attempt to reuse previous SAD computations due to the engineering complexity

## Correct Conclusion

The Diamond Search algorithm's computational advantages come from superior algorithmic design rather than SAD computation reuse. The 22% less computation compared to NTSS is achieved through better search pattern efficiency and algorithmic optimization rather than reusing previous SAD values.

Your concern about the additional routing complexity and memory bandwidth requirements being worse than additional SAD engines is absolutely correct. This is why DS implementations don't attempt true SAD reuse - the engineering cost would outweigh the computational benefits.

The DS algorithm's efficiency comes from its well-designed search pattern that naturally exploits the characteristics of real-world motion vectors, rather than from complex computation reuse mechanisms that would require significant additional hardware complexity.
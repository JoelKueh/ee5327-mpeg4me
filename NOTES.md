
# EE5327 - MPEG4 Motion Estimation

## Search Algorithm Overview

- Full Search (FS)
    - Computationally expensive
    - Produces global minimum matching error point over the search window
- Block-Matching Motion Estimationi
    - Attempts to mimic FS but with lower computational cost
    - Different Algorithms
        - 2-D Logarithmic Search (LOGS)
        - Three-Step Search (TSS)
        - Conjugate Direction Search (CDS)
        - New Three-Step Search (NTSS)
        - Four-Step Search (4SS)
        - Block-Based Gradient Descent Search (BBGDS)
        - Diamond Search (DS) and its derivatives?

## Diamond Search Algorithm

- A method of *block-matching motion estimation* (BMME)

### Theory

NOTE: What are "Checking Points"

NOTE: What are "Pels"

#### Observations

- Block distortions (matching errors) form an error surface over the window
    - The optimum point is where the error surface is minimum
    - Error surface is not monotonic (local minima)
    - More local minima in video with large motion content
- The search patterns shape and size determine search speed and resulted performance.
    - Small search patterns (3x3 in BBGDS) are likely to get caught in local minima
    - Large search patterns (9x9 first step in TSS) mislead path in wrong direction
    - **Need a happy medium search pattern**
- Distribution of global minima in real-world video is centered around zero motion (window center)
    - This is why the center-biased NTSS achieves much better performance than TSS
        - Achieves better results and requires fewer search points.
- NTSS, 4SS, and BBGDS
    - NTSS loses the regularity and simplicity of TSS to some extent?
    - 4SS has similar performance to NTSS
    - NTSS and 4SS utilize the overlapping of checking points between adjacent search steps
    - Reduces computational complexity further
    - 4SS requires you to test 17 checking points for a stationary block.
    - BBGDS only requires 9 checking points for a stationary block.
    - BBGDS, TSS, NTSS, and 4SS use 15x15 search window size to fit their framework.
- Block displacement is primarily in the horrizontal and vertical directions (camera panning)

#### Basics

- Employs two search patterns
    - Large Diamond Search Pattern (LDSP) - Nine checking points (eight around center in diamond)
    - Small Diamond Search Pattern (SDSP) - Five checking points (4 around center in diamond)
- LDSP is repeatedly used until the minimum block distortion (MBD) occurs at the center point.
    - Moving from LDSP to LDSP, you can reuse computation from the previous stage.
- SDSP is used after LDSP?

##### LDSP Pattern

There are 13 possible checking points in a radum of 2 pels

```
. . x . .
. x x x .
x x x x x
. x x x .
. . x . .
```

Only 9 of these are used for the LDSP

```
. . x . .
. x . x .
x . x . x
. x . x .
. . x . .
```

Moving from edge to edge on the LDSP, you can reuse some previously tested results.

```
Corner        Edge
=========     ===========
. . y . . .   . . . . . .
. y . y . .   . . . y . .
y . x . y .   . . x . y .
. x . x . .   . x . x . y
x . x . x .   x . x . x .
. x . x . .   . x . x . .
. . x . . .   . . x . . .
```

##### SDSP

Swapping to the 5-point SDSP at the end allows you to test the interior, untested LDSP points.

```
. . . . .
. . x . .
. x x x .
. . x . .
. . . . .
```

### Algorithm

#### Summary

1. Initial LDSP is centered at the origin of the search window, and 9 checking points are tested.
    - If the MBD is at the center position go to **Step 3** (SDSP) otherwise **Step 2**
2. The MBD point for the previous search is the new center point for LDSP.
3. Use SDSP for the final search. The MBD point found in this step is the final solution.

#### Implementation Details

- Cull the checking points outside the search window boundary.
    - The search is confined within the search window boundary
    - **What is the search window?**
- DS does not restrict the total number of search steps
    - Monotonically decreasing path in search must be finite length.
    - Simple tie-breaking philosophy should break all infinite loops.


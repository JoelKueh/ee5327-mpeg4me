#import "@preview/cetz:0.3.4"

#set page(paper: "us-letter", margin: 0.75in)
#set text(size: 12pt)
#show raw.where(block: true): it => block(
  fill: luma(240),
  inset: 10pt,
  radius: 4pt,
  width: 100%,
  it
)

#align(center)[
  #text(size: 16pt, weight: "bold")[
    EE5327 VLSI Design Project, Report 1
  ]

  Submitted by: Joel Kuehne, Email ID: kuehn348\@umn.edu
]

= Introduction

Motion estimation is the most computationally intensive task in H.264/H.265 video encoding,
accounting for around 80% of the total computational for video encoding @one-bit. As the
name implies, motion estimators improve encoding efficiency by identifying movement over time in
the source video. The objective of any motion estimation algorithm is to produce an array of 
optimal motion vectors (MVs) that describe change over time between the current frame and a
previous reference frame. Compression standards like Advanced Video Coding (AVC/H.264) and
High Efficiency Video Coding (HEVC/H.265) support variable-block-size prediction. In H.264, a
variable-block-size motion estimation algorithm produces the optimal displacement vector for 
each 16x16 macroblock and all of their supported subdivisions (4x4, 4x8, 8x4, 8x8, 8x16, and 16x8).

#figure(
  cetz.canvas(length: 0.45cm, {
    import cetz.draw: *
  
    // 1. Background fill and outer 16x16 Macroblock border
    rect((0, 0), (16, 16), fill: rgb("#f8fafc"), stroke: 2.5pt + rgb("#1e293b"))
  
    // 2. Main 8x8 quadrant dividers (Sub-macroblocks)
    line((8, 0), (8, 16), stroke: 1.5pt + rgb("#334155"))
    line((0, 8), (16, 8), stroke: 1.5pt + rgb("#334155"))
  
    // 3. Sub-partitioning within each 8x8 quadrant:
    
    // Top-Left (0,8 to 8,16): Kept as a single 8x8 partition
    content((4, 12), [*8×8*])
  
    // Top-Right (8,8 to 16,16): Split horizontally into two 8x4 partitions
    line((8, 12), (16, 12), stroke: (paint: rgb("#2563eb"), thickness: 1pt, dash: "dashed"))
    content((12, 14), text(fill: rgb("#1d4ed8"))[*8×4*])
    content((12, 10), text(fill: rgb("#1d4ed8"))[*8×4*])
  
    // Bottom-Left (0,0 to 8,8): Split vertically into two 4x8 partitions
    line((4, 0), (4, 8), stroke: (paint: rgb("#059669"), thickness: 1pt, dash: "dashed"))
    content((2, 4), text(fill: rgb("#047857"))[*4×8*])
    content((6, 4), text(fill: rgb("#047857"))[*4×8*])
  
    // Bottom-Right (8,0 to 16,8): Split into four 4x4 partitions
    line((12, 0), (12, 8), stroke: (paint: rgb("#d97706"), thickness: 1pt, dash: "dashed"))
    line((8, 4), (16, 4), stroke: (paint: rgb("#d97706"), thickness: 1pt, dash: "dashed"))
    content((10, 6), text(fill: rgb("#b45309"), size: 9pt)[*4×4*])
    content((14, 6), text(fill: rgb("#b45309"), size: 9pt)[*4×4*])
    content((10, 2), text(fill: rgb("#b45309"), size: 9pt)[*4×4*])
    content((14, 2), text(fill: rgb("#b45309"), size: 9pt)[*4×4*])
    
    // Top dimension line (16 px)
    line((0, -0.8), (16, -0.8), mark: (start: "|", end: "|"), stroke: 0.7pt + gray)
    content((8, -0.8), box(fill: white, inset: 3pt)[16 luma samples])
    
    // Left dimension line (8 px top + 8 px bottom)
    line((-0.8, 8), (-0.8, 16), mark: (start: "|", end: "|"), stroke: 0.7pt + gray)
    content((-2.0, 12), [8 px])
    line((-0.8, 0), (-0.8, 8), mark: (start: "|", end: "|"), stroke: 0.7pt + gray)
    content((-2.0, 4), [8 px])
  }),
  caption: [Example of the different subdivisions of a $16 times 16$ macroblock in H.264.]
)

Formally, finding the best motion vector can be modeled as finding the minimum of a distance
objective function over a finite search window. Sum of Absolute Differences (SAD) is
the objective function of choice for almost all motion estimation algorithms. Various architectures
and algorithms have been proposed for efficient motion estimation. In hardware, fast-search
algorithms such as three step search (TSS), four step search (4SS), and diamond search (DS) achieve
better computational efficiency by performing a sequential search of the objective function.
Advanced fast-search algorithms like Enhanced Predictive Zonal Search (EPZS) and variants of the
cross-diamond-hexagonal search achieve high encoding efficiency at a lower compute cost @hwmds.
These advanced fast-search algorithms work well in software, but do not map well to hardware.

Many fast-search motion estimation algorithms assume a unimodal objective function with a global
minimum. This assumption is often invalid for real video @key. Full-search motion estimation
abandons this sequential search approach and produces the absolute minimum over the finite search
window by computing and comparing all possible SAD results for every subdivision of every
macroblock. Because full-search motion estimation is guaranteed to find the minimum over SAD over
the search space, it achieves higher encoding efficiencies than sequential fast-search methods.

This project implements a modified version of the streaming architecture for HEVC/H.265 motion
estimation discussed in @key. The modified architecture drops support for H.265 in favor of the
less computationally expensive H.264 to reduce gate count and area.

#pagebreak()
#bibliography("works.bib")

#import "@preview/touying:0.6.1": *
#import themes.metropolis: *
#import "theme.typ": *

#show raw: set text(size: 9.3pt)
#show raw.where(block: true): it => block(
  fill: luma(240),
  inset: 4pt,
  radius: 4pt,
  width: 100%,
  it
)

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  footer: self => self.info.institution,
  config-page(
    header: self => {
      set align(top)
      block(
        width: 100%,
        fill: umn-maroon,
        inset: (x: 1.5em, y: 0.7em),
        text(fill: white, weight: "semibold", size: 1.1em, utils.display-current-heading(level: 2)),
      )
    },
  ),
  config-info(
    title: [EE5327 Project Report: H.264 Motion Estimation],
    author: [Joel Kuehne],
    date: datetime.today(),
    institution: [University of Minnesota],
  ),
  config-colors(
    primary: umn-maroon,
    primary-light: umn-maroon.lighten(85%),
    secondary: umn-maroon,
    neutral-lightest: umn-off-white,
    neutral-darkest: umn-dark-gray,
  ),
)

#show strong: set text(fill: umn-dark-gray, weight: "bold")

#title-slide()

== Introduction: H.264 Variable Block Size Motion Estimation (VBSME)

#components.side-by-side(
  columns: (1.1fr, 1fr),
  gutter: 1.5em,
  [
    - *Motion Compensation:* Match blocks in the current frame to a reference frame 

    - *Sum of Absolute Differences (SAD):*
      - Objective function for Motion Estimation
      - Computed on the luma component

    - *Partitioning:* $16 times 16$ macroblock splits into smaller blocks ($16 times 16$ down to $4 times 4$)
  ],
  include "diagrams/h264.typ"
)

// == Introduction: Motion Estimation
// 
// #components.side-by-side(
//   columns: (1.0fr, 0.7fr),
//   gutter: 1.5em,
//   [
//     - *Sum of Absolute Differences (SAD):*
//       - Objective function for Motion Estimation
//       - Computed on the luma component (brightness)
// 
//     - *Fast Search Motion Estimation:*
//       - Test a limited set of motion vectors
//       - Sequential, iterative process
// 
//     - *Full Search Motion Estimation:*
//       - Test all candidate motion vectors
//       - Massively parallel process
//   ],
//   include "diagrams/subdivisions.typ"
// )

== Reference Design: HEVC/H.265 Full Search

#components.side-by-side(
  columns: (1.0fr, 1.00fr),
  gutter: 1.5em,
  [
    - *SAD Computation:*
      - Use four PE Arrays to compute four \ $4 times 4$ blocks in parallel
      - Combine $4 times 4$ into $8 times 8$
    
    - *SAD Summation:*
      - Combine $n times n$ into $2n times 2n$
      - Use SRAM to store intermediate results

    - *SAD Comparator:*
      - Reduction tree aggregates row results
      - Minimum is stored in a register
  ],
  include "diagrams/reference.typ"
)

== Reference Design: Processing Engine Array

#include "diagrams/pe_array.typ"

== Updated Design: HEVC/H.265 to AVC/H.264

#components.side-by-side(
  columns: (1.0fr, 1.00fr),
  gutter: 1.5em,
  [
    - *Reduced Search Window Size:*
      - Reference uses $64 times 64$ search window 
      - My design reduces this to $32 times 32$

    - *Reduced Maximum Block Size:*
      - H.265 supports block size up to $64 times 64$
      - H.264 supports up to $16 times 16$
  ],
  include "diagrams/updates1.typ",
)

// == Updated Design: Reworked Computation Stage
// 
// #include "diagrams/updates2.typ"

== Updated Design: Reworked Processing Engine

#components.side-by-side(
  columns: (1.0fr, 1.0fr),
  gutter: 1.5em,
  [
    - *Row Merging*
      - Reuse massive adder trees
      - Throughput cut by four

    - *Datapath Width Reduction*
      - Stream output over four cycles
      - Datapath width cut by four

    - *SRAM Width*
      - Rebalanced from 32x400 to 128x100
      - Improves routability and bit density
  ],
  include "diagrams/pe.typ"
)

== Verification: SVUnit Testbenches

#components.side-by-side(
  columns: (1.0fr, 1.1fr),
  gutter: 1.5em,
  [

    - *SVUnit Framework*
      - Mixture of random and directed tests
      - Behavioral model verifies results

    - *Testbenches*
      - Module-level - Tests extremes
      - Top-level - Tests typical behavior

    - *Tests*
      - Extremes - Max SAD, Min SAD
      - Control - Clear, Stall
      - Typical - Random Input
  ],
  [
    ```
    INFO:  [2650885][fs_combiner_ut]: PASSED (2 of 2 tests passing)
    INFO:  [2650885][fs_comparator_ut]: PASSED (2 of 2 tests passing)
    INFO:  [2650885][fs_computer_ut]: PASSED (4 of 4 tests passing)
    INFO:  [2650885][fs_control_ut]: PASSED (2 of 2 tests passing)
    INFO:  [2650885][fs_pe_ut]: PASSED (2 of 2 tests passing)
    INFO:  [2650885][fs_quarter_comparator_ut]: PASSED (4 of 4 tests passing)
    
    INFO:  [2650885][______src_tb_module_ts]: PASSED (6 of 6 testcases passing)
    
    INFO:  [2650885][testrunner]: PASSED (1 of 1 suites passing) [SVUnit Unreleased]
    ```
  ]
)

// == Verification: Waveforms
// 
// #figure(
//   image("images/pe_output.png", width: 90%)
// )
// 
// #figure(
//   image("images/control_output_crop.png", width: 90%)
// )

== Evaluation: Performance

- Processes four $4 times 4$ sub-blocks per pass
- 156 cycles per pass for 32-row search window
- 624 cycles per macroblock (four passes)

#figure(
  table(
    columns: 5,
    [*Resolution*], [*Frame Rate*], [*Macroblock Count*], [*Clock Frequency*], [*Bandwidth*],
    [1920x1080], [30 Hz], [8100], [151.6 MHz], [1.541 GB/s],
    [1920x1080], [60 Hz], [8100], [303.3 MHz], [3.081 GB/s],
    [3840x2160], [30 Hz], [32400], [606.5 MHz], [6.162 GB/s],
    [3840x2160], [60 Hz], [32400], [1213.1 MHz], [12.325 GB/s]
  ),
  caption: [Performance of the design at different resolutions and frame rates.]
)

// NOTE: High bandwidth requirement is because the entire reference window is streamed from memory
// eight on all eight passes. By buffering the 48x48 search window in SRAM, we could avoid
// restreaming the reference frame on all 8 passes. By splitting this into three banks, we could
// make use of the fact that 2/3rds of the reference frame is reused between macroblocks. This
// would reduce the peak memory bandwidth of 16 bytes per cycle and an average bandwidth of 2.74
// bytes per cycle.

== Evaluation: Reference Comparison

// NOTE: NAND2 is 0.207360um^2

#figure(
  table(
    columns: 6,
    [*Metric*], [*Unit*], [*Design A*], [*Design B*], [*Design C*], [*Reference*], 
    [Process], [], [TSMC16], [TSMC16], [TSMC16], [TSMC32],
    [Gate Count], [k], [], [], [195], [2878],
    [Clock Frequency], [MHz], [272], [272], [607], [282],
    [Total Logic Area], [$mu"m"^2$], [99473], [53470], [30774], [],
    [Total SRAM Area], [$mu"m"^2$], [], [], [9496], [],
    [Total Cell Area], [$mu"m"^2$], [], [], [40270], []
  ),
  caption: [Comparison between my designs and the reference (3840x2160\@30fps).]
)

== Status

- Logic design and verification is complete
- The synthesized netlist has no constraints violations
- DFT insertion has been performed yielding 99.98% test coverage
- The design still has to be put through physical design


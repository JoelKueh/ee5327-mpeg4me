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
      - Motion vectors form a predicted frame
      - Better motion vectors improve quality

    - *Partitioning:* $16 times 16$ macroblock splits into 7 block sizes ($16 times 16$ down to $4 times 4$)
      - Large blocks capture uniform motion
      - Small blocks track complex edges
  ],
  include "diagrams/h264.typ"
)

== Introduction: Motion Estimation

#components.side-by-side(
  columns: (1.0fr, 0.7fr),
  gutter: 1.5em,
  [
    - *Sum of Absolute Differences (SAD):*
      - Objective function for Motion Estimation
      - Computed on the luma component (brightness)

    - *Fast Search Motion Estimation:*
      - Test a limited set of motion vectors
      - Sequential, iterative process
      - Greater memory bandwidth requirement

    - *Full Search Motion Estimation:*
      - Test all candidate motion vectors
      - Masively parallel process
      - Higher quality for greater computational cost
  ],
  include "diagrams/subdivisions.typ"
)

== Reference Design: HEVC/H.265 Fast Search

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

== Reference Design: Processing Element Array

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
      - My design removes two of the three summation stages
  ],
  include "diagrams/updates1.typ",
)

== Updated Design: Reworked Computation Stage

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
      - My design removes two of the three summation stages
  ],
  include "diagrams/updates2.typ",
)

== Verification: SVUnit Testbenches

#components.side-by-side(
  columns: (1.0fr, 1.0fr),
  gutter: 1.5em,
  [

    - *SVUnit Framework*
      - All tests are self-checking
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
    INFO:  [0][fs_combiner_ut]: RUNNING
    INFO:  [0][fs_combiner_ut]: typical::RUNNING
    INFO:  [7810][fs_combiner_ut]: typical::PASSED
    INFO:  [7810][fs_combiner_ut]: typical_stall::RUNNING
    INFO:  [17020][fs_combiner_ut]: typical_stall::PASSED
    INFO:  [17020][fs_comparator_ut]: RUNNING
    INFO:  [17020][fs_comparator_ut]: typical::RUNNING
    INFO:  [17755][fs_comparator_ut]: typical::PASSED
    INFO:  [17755][fs_comparator_ut]: typical_stall::RUNNING
    INFO:  [19175][fs_comparator_ut]: typical_stall::PASSED
    INFO:  [19175][fs_computer_ut]: RUNNING
    INFO:  [19175][fs_computer_ut]: test_clear::RUNNING
    INFO:  [19595][fs_computer_ut]: test_clear::PASSED
    INFO:  [19595][fs_computer_ut]: min_sad::RUNNING
    INFO:  [19955][fs_computer_ut]: min_sad::PASSED
    INFO:  [19955][fs_computer_ut]: max_sad::RUNNING
    INFO:  [20315][fs_computer_ut]: max_sad::PASSED
    INFO:  [20315][fs_computer_ut]: typical::RUNNING
    INFO:  [21135][fs_computer_ut]: typical::PASSED
    INFO:  [21135][fs_computer_ut]: typical_stall::RUNNING
    INFO:  [22385][fs_computer_ut]: typical_stall::PASSED
    INFO:  [22385][fs_computer_ut]: back_to_back_subblocks::RUNNING
    INFO:  [25305][fs_computer_ut]: back_to_back_subblocks::PASSED
    INFO:  [25305][fs_control_ut]: RUNNING
    INFO:  [25305][fs_control_ut]: typical_stall::RUNNING
    INFO:  [616545][fs_control_ut]: typical_stall::PASSED
    INFO:  [616545][fs_control_ut]: typical::RUNNING
    INFO:  [713445][fs_control_ut]: typical::PASSED
    ```
  ]
)

== Verification: Waveforms

#figure(
  image("images/computer_output.png", width: 90%)
)

#figure(
  image("images/control_output_crop.png", width: 90%)
)

== Evaluation: Performance

- Computes minimum SADs for two $4 times 4$ sub-blocks per pass.
- Each pass takes 35 cycles to stream the 35 rows from the refrence frame.
- It takes 280 cycles to process one macroblock.

#figure(
  table(
    columns: 5,
    [*Resolution*], [*Frame Rate*], [*Macroblock Count*], [*Clock Frequency*], [*Bandwidth*],
    [1920x1080], [30 Hz], [8100], [68.04 MHz], [2.716 GB/s],
    [1920x1080], [60 Hz], [8100], [136.08 MHz], [5.432 GB/s],
    [3840x2160], [30 Hz], [32400], [272.16 MHz], [10.863 GB/s],
    [3840x2160], [60 Hz], [32400], [544.32 MHz], [21.726 GB/s]
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

#figure(
  table(
    columns: 5,
    [*Metric*], [*Unit*], [*Original*], [*Modified*], [*Reference*], 
    [Process], [], [TSMC16], [TSMC16], [TSMC32],
    [Gate Count], [k], [282], [282], [2878],
    [Clock Frequency], [MHz], [282], [282], [282],
    [Total Logic Area], [$mu"m"^2$], [99473], [53470], [],
    [Total SRAM Area], [$mu"m"^2$], [20250], [31850], [],
    [Total Cell Area], [$mu"m"^2$], [119723], [85320], []
  ),
  caption: [Comparison between my designs and the reference at 282 MHz (3840x2160).]
)

== Status

- Logic design and verification is complete
- Optimization and design space exploration is complete
- DFT insertion has been performed yielding 99.3% coverage
- The design still has to be put through place and route


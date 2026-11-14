#import "@preview/touying:0.6.1": *
#import "@preview/cetz:0.4.2"
#import themes.metropolis: *

// UMN Colors
#let umn-maroon = rgb("#7A0019")
#let umn-gold = rgb("#FFCC33")
#let umn-dark-gold = umn-gold.darken(42%)
#let umn-dark-gray = rgb("#333333")
#let umn-off-white = rgb("#FAFAFA")

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

    - *Partitioning:* A $16 times 16$ macroblock splits into 7 block sizes ($16 times 16$ down to $4 times 4$)
      - Large blocks capture uniform motion
      - Small blocks track complex edges
  ],
  [
    #align(center + horizon)[
      #cetz.canvas(length: 1.2cm, {
        import cetz.draw: rect, line, content, circle

        // ==========================================
        // TOP DIAGRAM: Search Window & Motion Vector
        // ==========================================
        content((5.5, 9.1), text(size: 14pt, weight: "bold", fill: umn-maroon)[H.264 Block Matching])

        // Current Frame (Left): x in [0.4, 5.0] (width 4.6), y in [5.2, 8.5] -> center at (2.7, 6.85)
        rect((0.4, 5.2), (5.0, 8.5), stroke: 1pt + umn-dark-gray, fill: white)
        content((2.7, 4.8), text(size: 12.5pt, fill: umn-dark-gray)[Current Frame ($t$)])
        // Current Macroblock (16x16), 1.0x1.0 centered at (2.7, 6.85)
        rect((2.2, 6.35), (3.2, 7.35), stroke: 1.2pt + umn-maroon, fill: umn-maroon.lighten(85%))
        content((2.7, 6.85), text(size: 11pt, weight: "bold", fill: umn-maroon)[MB])

        // Reference Frame (Right): x in [6.0, 10.6] (width 4.6), y in [5.2, 8.5] -> center at (8.3, 6.85)
        rect((6.0, 5.2), (10.6, 8.5), stroke: 1pt + umn-dark-gray, fill: white)
        content((8.3, 4.8), text(size: 12.5pt, fill: umn-dark-gray)[Reference Frame ($t - 1$)])

        // Search Window [-p, +p] centered at (8.3, 6.85): +/- 1.8 in x, +/- 1.4 in y
        rect((6.5, 5.45), (10.1, 8.25), stroke: (paint: umn-dark-gold, thickness: 1pt, dash: "dashed"), fill: umn-gold.lighten(90%))
        content((8.3, 8.0), text(size: 10.0pt, weight: "bold", fill: umn-dark-gold)[Search Window])

        // Co-located origin block centered at (8.3, 6.85): bottom-left at (7.8, 6.35)
        rect((7.8, 6.35), (8.8, 7.35), stroke: (paint: umn-dark-gray, thickness: 0.8pt, dash: "dotted"), fill: none)

        // Best-match candidate block shifted by (+0.9, -0.55): bottom-left at (8.7, 5.8)
        rect((8.7, 5.8), (9.7, 6.8), stroke: 1.2pt + umn-maroon, fill: umn-maroon.lighten(85%))
        content((9.2, 6.3), text(size: 11pt, weight: "bold", fill: umn-maroon)[Best])

        // Motion Vector arrow from bottom-left (7.8, 6.35) to bottom-left (8.7, 5.8)
        line(
          (7.8, 6.35),
          (8.7, 5.8),
          stroke: 1.3pt + umn-dark-gray,
          mark: (end: "stealth", fill: umn-dark-gray, size: 0.18),
        )
        circle((7.8, 6.35), radius: 0.08, fill: umn-dark-gray)
        content((7.6, 5.65), text(size: 9pt, weight: "bold", fill: umn-dark-gray)[$arrow(v) = (Delta x, Delta y)$])

        // ==========================================
        // BOTTOM DIAGRAM: VBSME 7 Partition Modes
        // ==========================================
        content((5.5, 4.0), text(size: 14pt, weight: "bold", fill: umn-maroon)[H.264 Macroblock Partitions])

        // 16x16 (2.1 x 2.1, x: 0.4 to 2.5)
        rect((0.4, 1.3), (2.5, 3.4), stroke: 1.1pt + umn-dark-gray, fill: white)
        content((1.45, 0.92), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$16 times 16$])

        // 16x8 (2.1 x 2.1, x: 3.1 to 5.2)
        rect((3.1, 1.3), (5.2, 3.4), stroke: 1.1pt + umn-dark-gray, fill: white)
        line((3.1, 2.35), (5.2, 2.35), stroke: 0.9pt + umn-maroon)
        content((4.15, 0.92), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$16 times 8$])

        // 8x16 (2.1 x 2.1, x: 5.8 to 7.9)
        rect((5.8, 1.3), (7.9, 3.4), stroke: 1.1pt + umn-dark-gray, fill: white)
        line((6.85, 1.3), (6.85, 3.4), stroke: 0.9pt + umn-maroon)
        content((6.85, 0.92), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$8 times 16$])

        // 8x8 (2.1 x 2.1, x: 8.5 to 10.6)
        rect((8.5, 1.3), (10.6, 3.4), stroke: 1.1pt + umn-dark-gray, fill: white)
        line((9.55, 1.3), (9.55, 3.4), stroke: 0.9pt + umn-maroon)
        line((8.5, 2.35), (10.6, 2.35), stroke: 0.9pt + umn-maroon)
        content((9.55, 0.92), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$8 times 8$])

        // Sub-partition connector
        line(
          (9.55, 0.62),
          (9.55, 0.25),
          stroke: 1pt + umn-maroon,
          mark: (end: "stealth", fill: umn-maroon, size: 0.15),
        )
        content((7.65, 0.44), text(size: 11.5pt, style: "italic", fill: umn-maroon)[$8 times 8$ sub-modes:])

        // 8x4 (1.45 x 1.45, x: 4.25 to 5.70)
        rect((4.25, -1.25), (5.70, 0.2), stroke: 1.1pt + umn-dark-gray, fill: white)
        line((4.25, -0.525), (5.70, -0.525), stroke: 0.9pt + umn-maroon)
        content((4.975, -1.62), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$8 times 4$])

        // 4x8 (1.45 x 1.45, x: 6.55 to 8.00)
        rect((6.55, -1.25), (8.00, 0.2), stroke: 1.1pt + umn-dark-gray, fill: white)
        line((7.275, -1.25), (7.275, 0.2), stroke: 0.9pt + umn-maroon)
        content((7.275, -1.62), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$4 times 8$])

        // 4x4 (1.45 x 1.45, x: 8.85 to 10.30)
        rect((8.85, -1.25), (10.30, 0.2), stroke: 1.1pt + umn-dark-gray, fill: white)
        line((9.575, -1.25), (9.575, 0.2), stroke: 0.9pt + umn-maroon)
        line((8.85, -0.525), (10.30, -0.525), stroke: 0.9pt + umn-maroon)
        content((9.575, -1.62), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$4 times 4$])
      })
    ]
  ],
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
  [
    #align(center + horizon)[
      #cetz.canvas(length: 1.2cm, {
        import cetz.draw: rect, line, content

        // Title
        content((5.5, 9.1), text(size: 14pt, weight: "bold", fill: umn-maroon)[Spatial Decomposition into $4 times 4$ Atoms])

        // 16x16 Macroblock divided into 4x4 grid (size 5.2 x 5.2, from x: 0.4..5.6, y: 3.1..8.3)
        // Each 4x4 atom is 1.3 x 1.3
        rect((0.4, 3.1), (5.6, 8.3), stroke: 1.4pt + umn-dark-gray, fill: white)

        // Internal 4x4 grid lines
        line((1.7, 3.1), (1.7, 8.3), stroke: 0.7pt + umn-dark-gray.lighten(40%))
        line((3.0, 3.1), (3.0, 8.3), stroke: 0.7pt + umn-dark-gray.lighten(40%))
        line((4.3, 3.1), (4.3, 8.3), stroke: 0.7pt + umn-dark-gray.lighten(40%))

        line((0.4, 4.4), (5.6, 4.4), stroke: 0.7pt + umn-dark-gray.lighten(40%))
        line((0.4, 5.7), (5.6, 5.7), stroke: 0.7pt + umn-dark-gray.lighten(40%))
        line((0.4, 7.0), (5.6, 7.0), stroke: 0.7pt + umn-dark-gray.lighten(40%))

        // Top-Left: Highlight one 4x4 atom (x: 0.4..1.7, y: 7.0..8.3)
        rect((0.4, 7.0), (1.7, 8.3), stroke: (paint: umn-maroon, thickness: 1.4pt), fill: umn-maroon.lighten(90%))
        content((1.05, 7.65), text(size: 10.5pt, weight: "bold", fill: umn-maroon)[$4 times 4$])

        // Top-Right: Highlight an 8x4 horizontal pair (x: 3.0..5.6, y: 7.0..8.3)
        rect((3.0, 7.0), (5.6, 8.3), stroke: (paint: umn-dark-gold, thickness: 1.4pt), fill: umn-gold.lighten(88%))
        line((4.3, 7.0), (4.3, 8.3), stroke: 0.7pt + umn-dark-gold)
        content((4.3, 7.65), text(size: 10.5pt, weight: "bold", fill: umn-dark-gold)[$8 times 4$])

        // Bottom-Left: Highlight a 4x8 vertical pair (x: 0.4..1.7, y: 3.1..5.7)
        rect((0.4, 3.1), (1.7, 5.7), stroke: (paint: umn-dark-gold, thickness: 1.4pt), fill: umn-gold.lighten(88%))
        line((0.4, 4.4), (1.7, 4.4), stroke: 0.7pt + umn-dark-gold)
        content((1.05, 4.4), text(size: 10.5pt, weight: "bold", fill: umn-dark-gold)[$4 times 8$])

        // Bottom-Right: Highlight an 8x8 quadrant (x: 3.0..5.6, y: 3.1..5.7)
        rect((3.0, 3.1), (5.6, 5.7), stroke: (paint: umn-maroon, thickness: 1.4pt), fill: umn-maroon.lighten(90%))
        line((4.3, 3.1), (4.3, 5.7), stroke: 0.7pt + umn-maroon.lighten(40%))
        line((3.0, 4.4), (5.6, 4.4), stroke: 0.7pt + umn-maroon.lighten(40%))
        content((4.3, 4.4), text(size: 11.5pt, weight: "bold", fill: umn-maroon)[$8 times 8$])

        // Caption under grid
        content((3.0, 2.65), text(size: 12pt, fill: umn-dark-gray)[16 Atomic $4 times 4$ Blocks])

        // Right-side progression legend (x: 6.2..10.6)
        content((8.4, 7.8), text(size: 12.5pt, weight: "bold", fill: umn-dark-gray)[Hierarchical Union:])

        rect((6.3, 6.7), (10.5, 7.35), stroke: 1pt + umn-maroon, fill: umn-maroon.lighten(90%))
        content((8.4, 7.02), text(size: 11pt, weight: "bold", fill: umn-maroon)[$4 times 4$])

        content((8.4, 6.32), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$arrow.b$ Pairwise Sum])

        rect((6.3, 5.3), (10.5, 5.95), stroke: 1pt + umn-dark-gold, fill: umn-gold.lighten(90%))
        content((8.4, 5.62), text(size: 11pt, weight: "bold", fill: umn-dark-gold)[$8 times 4$, $4 times 8$])

        content((8.4, 4.92), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$arrow.b$ Quadrant Sum])

        rect((6.3, 3.9), (10.5, 4.55), stroke: 1pt + umn-maroon, fill: umn-maroon.lighten(90%))
        content((8.4, 4.22), text(size: 11pt, weight: "bold", fill: umn-maroon)[$8 times 8$])

        content((8.4, 3.52), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$arrow.b$ Macroblock Sum])

        rect((6.3, 2.5), (10.5, 3.15), stroke: 1pt + umn-dark-gray, fill: white)
        content((8.4, 2.82), text(size: 11pt, weight: "bold", fill: umn-dark-gray)[$16 times 8$, $8 times 16$, $16 times 16$])
      })
    ]
  ],
)

== Reference Design: HEVC/H.265 Fast Search

#components.side-by-side(
  columns: (1.0fr, 1.0fr),
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
  [
    #align(center + horizon)[
      #cetz.canvas(length: 1.2cm, {
        import cetz.draw: rect, line, content, circle

        // Column X ranges:
        // Left blocks (SAD comp / sum): x in [2.6, 5.4] (width 2.8, center 4.0)
        // Right blocks (SAD comparator): x in [6.2, 9.0] (width 2.8, center 7.6)
        // Row Y centers: 7.8, 5.6, 3.4, 1.2 (height 1.3 each -> +/- 0.65)

        let rows = (
          (y: 7.8, left-label: [SAD\ computation], depth: [3], is-first: true,  has-tap: true),
          (y: 5.6, left-label: [SAD\ summation],   depth: [2], is-first: false, has-tap: true),
          (y: 3.4, left-label: [SAD\ summation],   depth: [1], is-first: false, has-tap: true),
          (y: 1.2, left-label: [SAD\ summation],   depth: [0], is-first: false, has-tap: false),
        )

        // Top-left inputs into Row 0 (y = 7.8)
        line((1.5, 8.15), (2.6, 8.15), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((1.4, 8.15), anchor: "east", text(size: 11.5pt, fill: umn-dark-gray)[Ref. frame])

        line((1.5, 7.45), (2.6, 7.45), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((1.4, 7.45), anchor: "east", text(size: 11.5pt, fill: umn-dark-gray)[Current\ frame])

        for r in rows {
          let y = r.y
          let y-bot = y - 0.65
          let y-top = y + 0.65

          // Left block (SAD computation / summation)
          let left-stroke = if r.is-first { 1.3pt + umn-maroon } else { 1.2pt + umn-dark-gold }
          let left-fill = if r.is-first { umn-maroon.lighten(90%) } else { umn-gold.lighten(92%) }
          let left-text-fill = if r.is-first { umn-maroon } else { umn-dark-gold }

          rect((2.6, y-bot), (5.4, y-top), stroke: left-stroke, fill: left-fill)
          content((4.0, y), align(center, text(size: 12pt, weight: "bold", fill: left-text-fill, r.left-label)))

          // Horizontal arrow from Left block to SAD comparator
          line((5.4, y), (6.2, y), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))

          // Right block (SAD comparator)
          rect((6.2, y-bot), (9.0, y-top), stroke: 1.2pt + umn-dark-gray, fill: white)
          content((7.6, y), align(center, text(size: 12pt, fill: umn-dark-gray)[SAD\ comparator]))

          // Output arrow and MV_(depth = k) label
          line((9.0, y), (9.65, y), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
          content((9.75, y), anchor: "west", text(size: 12pt, weight: "bold", fill: umn-dark-gray)[MV#sub[(depth = #r.depth)]])

          // Tap & S-route down to the next row's SAD summation block
          if r.has-tap {
            let y-next = y - 2.2
            let y-mid = y - 1.1
            circle((5.75, y), radius: 0.075, fill: umn-dark-gray)
            line(
              (5.75, y),
              (5.75, y-mid),
              (2.05, y-mid),
              (2.05, y-next),
              (2.6, y-next),
              stroke: 1.1pt + umn-dark-gray,
              mark: (end: "stealth", fill: umn-dark-gray, size: 0.16),
            )
          }
        }
      })
    ]
  ],
)

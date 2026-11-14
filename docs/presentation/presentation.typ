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

    - *Partitioning:* $16 times 16$ macroblock splits into 7 block sizes ($16 times 16$ down to $4 times 4$)
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

        content((8.4, 6.32), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[Pairwise Sum])

        rect((6.3, 5.3), (10.5, 5.95), stroke: 1pt + umn-dark-gold, fill: umn-gold.lighten(90%))
        content((8.4, 5.62), text(size: 11pt, weight: "bold", fill: umn-dark-gold)[$8 times 4$, $4 times 8$])

        content((8.4, 4.92), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[Quadrant Sum])

        rect((6.3, 3.9), (10.5, 4.55), stroke: 1pt + umn-maroon, fill: umn-maroon.lighten(90%))
        content((8.4, 4.22), text(size: 11pt, weight: "bold", fill: umn-maroon)[$8 times 8$])

        content((8.4, 3.52), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[Macroblock Sum])

        rect((6.3, 2.5), (10.5, 3.15), stroke: 1pt + umn-dark-gray, fill: white)
        content((8.4, 2.82), text(size: 11pt, weight: "bold", fill: umn-dark-gray)[$16 times 8$, $8 times 16$, $16 times 16$])
      })
    ]
  ],
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
  [
    #align(center + horizon)[
      #cetz.canvas(length: 1.2cm, {
        import cetz.draw: rect, line, content, circle

        // Column X ranges:
        // Left blocks (SAD comp / sum): x in [2.6, 5.4] (width 2.8, center 4.0)
        // Right blocks (SAD comparator): x in [6.2, 9.0] (width 2.8, center 7.6)
        // Row Y centers: 7.8, 5.6, 3.4, 1.2 (height 1.3 each -> +/- 0.65)

        let rows = (
          (y: 7.8, left-label: [SAD\ Computation], depth: [3], is-first: true,  has-tap: true),
          (y: 5.6, left-label: [SAD\ Summation],   depth: [2], is-first: false, has-tap: true),
          (y: 3.4, left-label: [SAD\ Summation],   depth: [1], is-first: false, has-tap: true),
          (y: 1.2, left-label: [SAD\ Summation],   depth: [0], is-first: false, has-tap: false),
        )

        // Top-left inputs into Row 0 (y = 7.8)
        line((1.5, 8.15), (2.6, 8.15), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((1.4, 8.15), anchor: "east", text(size: 11.5pt, fill: umn-dark-gray)[Reference])

        line((1.5, 7.45), (2.6, 7.45), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((1.4, 7.45), anchor: "east", text(size: 11.5pt, fill: umn-dark-gray)[Current])

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
          content((7.6, y), align(center, text(size: 12pt, fill: umn-dark-gray)[SAD\ Comparator]))

          // Output arrow and MV_(depth = k) label
          line((9.0, y), (9.65, y), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
          content((9.75, y), anchor: "west", text(size: 12pt, weight: "bold", fill: umn-dark-gray)[MV])

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

== Reference Design: Processing Element Array

#align(center + horizon)[
  #cetz.canvas(length: 1.2cm, {
    import cetz.draw: rect, line, content, circle

    // Helper: Bus-width slash tick + label
    let bus-tick(x, y, lbl, dx: 0.22, dy: 0.16) = {
      line((x - 0.11, y - 0.11), (x + 0.11, y + 0.11), stroke: 1pt + umn-dark-gray)
      content((x + dx, y + dy), text(size: 10.5pt, weight: "bold", fill: umn-dark-gray)[#lbl])
    }

    // Helper: Trapezoid MUX
    let mux-top(cx, cy, w-top, w-bot, h, lbl) = {
      line(
        (cx - w-top / 2, cy + h / 2),
        (cx + w-top / 2, cy + h / 2),
        (cx + w-bot / 2, cy - h / 2),
        (cx - w-bot / 2, cy - h / 2),
        close: true,
        stroke: 1.2pt + umn-dark-gold,
        fill: umn-gold.lighten(90%),
      )
      content((cx, cy), text(size: 10.5pt, weight: "bold", fill: umn-dark-gold)[#lbl])
    }

    let mux-right(cx, cy, w, h-left, h-right, lbl) = {
      line(
        (cx - w / 2, cy + h-left / 2),
        (cx + w / 2, cy + h-right / 2),
        (cx + w / 2, cy - h-right / 2),
        (cx - w / 2, cy - h-left / 2),
        close: true,
        stroke: 1.2pt + umn-dark-gold,
        fill: umn-gold.lighten(90%),
      )
      content((cx, cy), rotate(90deg, text(size: 11.5pt, weight: "bold", fill: umn-dark-gold)[#lbl]))
    }

    // Grid geometry
    let row-ys = (6.8, 4.95, 3.1, 1.25)
    let col-xs = (4.4, 6.25, 8.1, 9.95)
    let pe-r = 0.42
    let bus-off = 0.78

    // ==========================================
    // 1. CF DATA BUFFER & FEEDBACK LOOP (LEFT)
    // ==========================================
    // Each register is vertically centered on its outgoing CF broadcast bus (y-cf = y + bus-off)
    let reg-half-h = 0.42
    let reg-top-0 = (row-ys.at(0) + bus-off) + reg-half-h // 8.00
    let reg-bot-3 = (row-ys.at(3) + bus-off) - reg-half-h // 1.61

    rect((1.05, reg-bot-3 - 0.25), (2.95, reg-top-0 + 0.25), stroke: (paint: umn-dark-gray, thickness: 0.9pt, dash: "dotted"), fill: none)
    content((0.75, (reg-top-0 + reg-bot-3) / 2), rotate(90deg, text(size: 12pt, weight: "bold", fill: umn-dark-gray)[CF data buffer]))

    // Top 2:1 MUX
    mux-top(2.0, 8.85, 1.35, 0.75, 0.55, [MUX])
    content((2.35, 10.10), align(center, text(size: 12pt, weight: "bold", fill: umn-dark-gray)[Current Frame]))
    line((2.35, 9.75), (2.35, 9.125), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.15))
    line((2.0, 8.575), (2.0, reg-top-0), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.15))

    // Feedback loop from bottom register back into top MUX
    line(
      (2.0, reg-bot-3),
      (2.0, 0.85),
      (0.25, 0.85),
      (0.25, 9.55),
      (1.65, 9.55),
      (1.65, 9.125),
      stroke: 1.1pt + umn-dark-gray,
      mark: (end: "stealth", fill: umn-dark-gray, size: 0.15),
    )
    bus-tick(2.0, 1.22, [4], dx: -0.22, dy: 0.02)

    // ==========================================
    // 2. REF. FRAME DATA FAN-OUT (TOP)
    // ==========================================
    content((7.55, 10.10), align(center, text(size: 12pt, weight: "bold", fill: umn-dark-gray)[Reference Frame]))
    line((7.55, 9.75), (7.55, 9.15), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.15))
    bus-tick(7.55, 9.48, [L+3], dx: 0.44, dy: 0.0)

    // Vertical Ref. Frame buses (0.78 right of each PE column)
    for c in range(4) {
      let x-bus = col-xs.at(c) + bus-off
      line((7.55, 9.15), (x-bus, 8.6), (x-bus, 1.25), stroke: 1.1pt + umn-dark-gray)
      bus-tick(x-bus, 8.22, [4], dx: -0.22, dy: 0.02)
    }

    // ==========================================
    // 3. ROWS: BUFFERS, CF BUSES, PEs, SAD BUSES
    // ==========================================
    for r in range(4) {
      let y = row-ys.at(r)
      let y-cf = y + bus-off
      let y-sad = y - 0.65
      let reg-bot = y-cf - reg-half-h
      let reg-top = y-cf + reg-half-h

      // CF Buffer register box centered on y-cf
      rect((1.25, reg-bot), (2.75, reg-top), stroke: 1.2pt + umn-dark-gray, fill: white)

      // Inter-stage vertical shift connection
      if r < 3 {
        let y-next-top = (row-ys.at(r + 1) + bus-off) + reg-half-h
        line((2.0, reg-bot), (2.0, y-next-top), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.15))
        bus-tick(2.0, (reg-bot + y-next-top) / 2, [4], dx: -0.22, dy: 0.0)
      }

      // Horizontal CF broadcast bus exiting center of register above row r
      line((2.75, y-cf), (col-xs.at(3), y-cf), stroke: 1.1pt + umn-dark-gray)
      bus-tick(3.3, y-cf, [4], dx: 0.0, dy: 0.22)

      // Horizontal SAD collector bus below row r into right MUX
      line((col-xs.at(0), y-sad), (11.0, y-sad), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.15))

      // 4 Processing Elements (PEs) in row r
      for c in range(4) {
        let x = col-xs.at(c)
        let x-ref = x + bus-off

        // PE Circle
        circle((x, y), radius: pe-r, stroke: 1.3pt + umn-maroon, fill: umn-maroon.lighten(90%))
        content((x, y), text(size: 11.5pt, weight: "bold", fill: umn-maroon)[PE])

        // Top tap: CF bus -> top of PE
        line((x, y-cf), (x, y + pe-r), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.13))

        // Right tap: Ref bus -> right of PE
        line((x-ref, y), (x + pe-r, y), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.13))

        // Bottom tap: bottom of PE -> SAD collector bus
        line((x, y - pe-r), (x, y-sad), stroke: 1.1pt + umn-dark-gray)
      }
    }

    // ==========================================
    // 4. OUTPUT MUX & X DIMENSION ARROW
    // ==========================================
    mux-right(11.4, 3.375, 0.75, 6.8, 5.2, [MUX])
    line((11.775, 3.375), (12.45, 3.375), stroke: 1.2pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
    content((12.55, 3.375), anchor: "west", text(size: 12.5pt, weight: "bold", fill: umn-dark-gray)[SAD])

    // X dimension arrow below array
    line((col-xs.at(0), 0.15), (col-xs.at(3), 0.15), stroke: 1pt + umn-dark-gray, mark: (start: "stealth", end: "stealth", fill: umn-dark-gray, size: 0.14))
    line((col-xs.at(0), 0.0), (col-xs.at(0), 0.3), stroke: 1pt + umn-dark-gray)
    line((col-xs.at(3), 0.0), (col-xs.at(3), 0.3), stroke: 1pt + umn-dark-gray)
    content(((col-xs.at(0) + col-xs.at(3)) / 2, 0.00), fill: umn-off-white, inset: 2pt, text(size: 12pt, weight: "bold", fill: umn-dark-gray)[x])
  })
]

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
  [
    #align(center + horizon)[
      #cetz.canvas(length: 1.2cm, {
        import cetz.draw: rect, line, content, circle

        // ==========================================
        // TOP DIAGRAM: Reduced 2-Stage H.264 Pipeline
        // ==========================================
        content((5.5, 9.1), text(size: 14pt, weight: "bold", fill: umn-maroon)[1. Single-Stage H.264 SAD Summation])

        let rows = (
          (y: 7.7, left-label: [SAD\ Computation], is-first: true,  has-tap: true),
          (y: 5.5, left-label: [SAD\ Summation],   is-first: false, has-tap: false),
        )

        // Top-left inputs into Row 0 (y = 7.7)
        line((1.5, 8.02), (2.6, 8.02), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((1.4, 8.02), anchor: "east", text(size: 11.5pt, fill: umn-dark-gray)[Reference])

        line((1.5, 7.38), (2.6, 7.38), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((1.4, 7.38), anchor: "east", text(size: 11.5pt, fill: umn-dark-gray)[Current])

        for r in rows {
          let y = r.y
          let y-bot = y - 0.6
          let y-top = y + 0.6

          let left-stroke = if r.is-first { 1.3pt + umn-maroon } else { 1.2pt + umn-dark-gold }
          let left-fill = if r.is-first { umn-maroon.lighten(90%) } else { umn-gold.lighten(92%) }
          let left-text-fill = if r.is-first { umn-maroon } else { umn-dark-gold }

          rect((2.6, y-bot), (5.4, y-top), stroke: left-stroke, fill: left-fill)
          content((4.0, y), align(center, text(size: 12pt, weight: "bold", fill: left-text-fill, r.left-label)))

          // Horizontal arrow from Left block to SAD comparator
          line((5.4, y), (6.2, y), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))

          // Right block (SAD comparator)
          rect((6.2, y-bot), (9.0, y-top), stroke: 1.2pt + umn-dark-gray, fill: white)
          content((7.6, y), align(center, text(size: 12pt, fill: umn-dark-gray)[SAD\ Comparator]))

          // Output arrow and MV label
          line((9.0, y), (9.65, y), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
          content((9.75, y), anchor: "west", text(size: 12pt, weight: "bold", fill: umn-dark-gray)[MV])

          // Tap & S-route down to the SAD summation block
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

        // ==========================================
        // BOTTOM DIAGRAM: Search Window Reduction
        // ==========================================
        content((5.5, 4.1), text(size: 14pt, weight: "bold", fill: umn-maroon)[2. Search Window Reduction ($64 times 64 arrow.r 32 times 32$)])

        // Left: H.265 64x64 Search Window (3.0 x 3.0, x: 1.2..4.2, y: 0.5..3.5 -> center 2.7, 2.0)
        rect((1.2, 0.5), (4.2, 3.5), stroke: (paint: umn-dark-gray, thickness: 1.2pt, dash: "dashed"), fill: white)
        // 16x16 MB inside (0.75 x 0.75 -> 1/4 width)
        rect((2.325, 1.625), (3.075, 2.375), stroke: 1.2pt + umn-maroon, fill: umn-maroon.lighten(85%))
        content((2.7, 2.0), text(size: 10.5pt, weight: "bold", fill: umn-maroon)[MB])
        content((2.7, 0.12), text(size: 12pt, fill: umn-dark-gray)[Reference: $64 times 64$])

        // Center transition arrow + area reduction callout
        line((4.65, 2.0), (6.35, 2.0), stroke: 1.4pt + umn-maroon, mark: (end: "stealth", fill: umn-maroon, size: 0.2))
        content((5.5, 2.42), text(size: 12pt, weight: "bold", fill: umn-maroon)[$4 times$ Fewer])
        content((5.5, 1.58), text(size: 11.5pt, fill: umn-dark-gray)[Candidates])

        // Right: H.264 32x32 Search Window (true 1/2 linear scale: 1.5 x 1.5, x: 7.55..9.05, y: 1.25..2.75 -> center 8.3, 2.0)
        rect((7.55, 1.25), (9.05, 2.75), stroke: (paint: umn-dark-gray, thickness: 1.3pt, dash: "dashed"), fill: white)
        // Same 16x16 MB inside (0.75 x 0.75)
        rect((7.925, 1.625), (8.675, 2.375), stroke: 1.2pt + umn-maroon, fill: umn-maroon.lighten(85%))
        content((8.3, 2.0), text(size: 10.5pt, weight: "bold", fill: umn-maroon)[MB])
        content((8.3, 0.12), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[Updated: $32 times 32$])
      })
    ]
  ],
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
  [
    #align(center + horizon)[
      #cetz.canvas(length: 1.2cm, {
        import cetz.draw: rect, line, content, circle

        // Helper: Adder / Combiner circle with diagonal cross
        let adder-node(cx, cy, r: 0.58) = {
          circle((cx, cy), radius: r, stroke: 1.2pt + umn-dark-gray, fill: white)
          let d = r * calc.cos(45deg)
          line((cx - d, cy - d), (cx + d, cy + d), stroke: 1pt + umn-dark-gray)
          line((cx - d, cy + d), (cx + d, cy - d), stroke: 1pt + umn-dark-gray)
        }

        let x-left = 3.2
        let x-right = 7.4
        let x-mid = (x-left + x-right) / 2 // 5.3
        let r-add = 0.58

        // ==========================================
        // 1. TOP INPUT FAN-OUT
        // ==========================================
        content((x-mid, 9.25), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[Reference Block / Current Block])
        line((x-mid, 8.95), (x-mid, 8.45), stroke: 1.1pt + umn-dark-gray)
        line((x-left, 8.45), (x-right, 8.45), stroke: 1.1pt + umn-dark-gray)
        line((x-left, 8.45), (x-left, 7.85), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        line((x-right, 8.45), (x-right, 7.85), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))

        // ==========================================
        // 2. PE ARRAYS (ROW 1)
        // ==========================================
        // PE Array 0 (x: 2.2..4.2, y: 6.45..7.85)
        rect((x-left - 1.0, 6.45), (x-left + 1.0, 7.85), stroke: 1.3pt + umn-maroon, fill: umn-maroon.lighten(90%))
        content((x-left, 7.15), text(size: 12pt, weight: "bold", fill: umn-maroon)[PE Array 0])

        // PE Array 1 (x: 6.4..8.4, y: 6.45..7.85)
        rect((x-right - 1.0, 6.45), (x-right + 1.0, 7.85), stroke: 1.3pt + umn-maroon, fill: umn-maroon.lighten(90%))
        content((x-right, 7.15), text(size: 12pt, weight: "bold", fill: umn-maroon)[PE Array 1])

        // ==========================================
        // 3. UPPER ADDER (4x8) & SRAMs (ROW 2)
        // ==========================================
        let y-add-top = 5.75
        adder-node(x-mid, y-add-top, r: r-add)

        // Vertical lines from PE Arrays down to SRAMs + horizontal taps to 4x8 adder
        line((x-left, 6.45), (x-left, 4.95), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        line((x-left, y-add-top), (x-mid - r-add, y-add-top), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))

        line((x-right, 6.45), (x-right, 4.95), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        line((x-right, y-add-top), (x-mid + r-add, y-add-top), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))

        // 4x8 output arrow
        line((x-mid, y-add-top - r-add), (x-mid, 4.25), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((x-mid, 3.92), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$4 times 8$])

        // SRAM A (x: 2.2..4.2, y: 3.55..4.95)
        rect((x-left - 1.0, 3.55), (x-left + 1.0, 4.95), stroke: 1.2pt + umn-dark-gold, fill: umn-gold.lighten(92%))
        content((x-left, 4.25), text(size: 12pt, weight: "bold", fill: umn-dark-gold)[SRAM A])

        // SRAM B (x: 6.4..8.4, y: 3.55..4.95)
        rect((x-right - 1.0, 3.55), (x-right + 1.0, 4.95), stroke: 1.2pt + umn-dark-gold, fill: umn-gold.lighten(92%))
        content((x-right, 4.25), text(size: 12pt, weight: "bold", fill: umn-dark-gold)[SRAM B])

        // ==========================================
        // 4. LOWER ADDERS (8x4, 8x8) & OUTER 4x4 BYPASSES
        // ==========================================
        let y-add-mid = 2.35
        let y-add-bot = 1.25
        let y-out = 0.25

        // Left & Right 8x4 adders
        adder-node(x-left, y-add-mid, r: r-add)
        adder-node(x-right, y-add-mid, r: r-add)

        // SRAM -> 8x4 adder vertical arrows
        line((x-left, 3.55), (x-left, y-add-mid + r-add), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        line((x-right, 3.55), (x-right, y-add-mid + r-add), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))

        // Outer bypass lines from PE Arrays -> 4x4 outputs + horizontal taps into 8x4 adders
        let x-bypass-l = 1.45
        let x-bypass-r = 9.15

        line((x-left - 1.0, 7.15), (x-bypass-l, 7.15), (x-bypass-l, y-out), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        line((x-bypass-l, y-add-mid), (x-left - r-add, y-add-mid), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((x-bypass-l, -0.1), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$4 times 4$])

        line((x-right + 1.0, 7.15), (x-bypass-r, 7.15), (x-bypass-r, y-out), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        line((x-bypass-r, y-add-mid), (x-right + r-add, y-add-mid), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((x-bypass-r, -0.1), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$4 times 4$])

        // 8x4 outputs down to bottom
        line((x-left, y-add-mid - r-add), (x-left, y-out), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((x-left, -0.1), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$8 times 4$])

        line((x-right, y-add-mid - r-add), (x-right, y-out), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((x-right, -0.1), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$8 times 4$])

        // Bottom center 8x8 adder + horizontal taps from 8x4 outputs
        adder-node(x-mid, y-add-bot, r: r-add)
        line((x-left, y-add-bot), (x-mid - r-add, y-add-bot), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        line((x-right, y-add-bot), (x-mid + r-add, y-add-bot), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))

        line((x-mid, y-add-bot - r-add), (x-mid, y-out), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.16))
        content((x-mid, -0.1), text(size: 12pt, weight: "bold", fill: umn-dark-gray)[$8 times 8$])
      })
    ]
  ]
)


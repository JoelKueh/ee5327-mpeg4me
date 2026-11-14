
#import "../theme.typ": *

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

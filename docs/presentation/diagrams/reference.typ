
#import "../theme.typ": *

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

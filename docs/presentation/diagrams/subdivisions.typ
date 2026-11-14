
#import "../theme.typ": *

#align(center + horizon)[
  #cetz.canvas(length: 1.2cm, {
    import cetz.draw: rect, line, content

    // Title
    content((5.5, 9.1), text(size: 14pt, weight: "bold", fill: umn-maroon)[Spatial Decomposition])

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

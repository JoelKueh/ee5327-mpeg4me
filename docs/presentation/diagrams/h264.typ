
#import "../theme.typ": *

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

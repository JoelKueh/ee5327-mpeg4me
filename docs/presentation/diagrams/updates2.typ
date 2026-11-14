
#import "../theme.typ": *

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


#import "../theme.typ": *

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

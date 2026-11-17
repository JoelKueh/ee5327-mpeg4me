#import "../theme.typ": *

#align(center + horizon)[
  #cetz.canvas(length: 1.2cm, {
    import cetz.draw: rect, line, content, circle

    // Helper: White circular arithmetic node (+ or -)
    let op-circle(cx, cy, r, lbl, sz: 14pt) = {
      circle((cx, cy), radius: r, stroke: 1.2pt + umn-dark-gray, fill: white)
      content((cx, cy), text(size: sz, weight: "bold", fill: umn-dark-gray)[#lbl])
    }

    // Helper: 2:1 MUX trapezoid (inputs on right, output on left)
    let mux-right-to-left(cx, cy, w, h-right, h-left) = {
      line(
        (cx + w / 2, cy + h-right / 2),
        (cx + w / 2, cy - h-right / 2),
        (cx - w / 2, cy - h-left / 2),
        (cx - w / 2, cy + h-left / 2),
        close: true,
        stroke: 1.2pt + umn-dark-gold,
        fill: umn-gold.lighten(90%),
      )
      content((cx, cy), rotate(90deg, text(size: 10.5pt, weight: "bold", fill: umn-dark-gold)[MUX]))
    }

    // Helper: D Flip-Flop register with clock triangle
    let dff-box(cx, cy, w, h, lbl) = {
      rect((cx - w / 2, cy - h / 2), (cx + w / 2, cy + h / 2), stroke: 1.2pt + umn-dark-gold, fill: umn-gold.lighten(92%))
      content((cx, cy + 0.08), text(size: 11.5pt, weight: "bold", fill: umn-dark-gold)[#lbl])
      line(
        (cx - 0.14, cy - h / 2),
        (cx, cy - h / 2 + 0.18),
        (cx + 0.14, cy - h / 2),
        stroke: 1pt + umn-dark-gold,
      )
    }

    // ==========================================
    // 1. 4 PARALLEL SUBTRACTORS (TOP)
    // ==========================================
    let lane-xs = (1.6, 3.4, 5.2, 7.0)
    let y-sub = 7.45
    let r-sub = 0.48

    for i in range(4) {
      let x = lane-xs.at(i)

      // rb and cb inputs (clean labels, plenty of separation)
      content((x - 0.38, 8.62), text(size: 11pt, weight: "bold", fill: umn-dark-gray)[rb])
      line((x - 0.38, 8.38), (x - 0.38, y-sub + 0.34), stroke: 1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.13))

      content((x + 0.38, 8.62), text(size: 11pt, weight: "bold", fill: umn-dark-gray)[cb])
      line((x + 0.38, 8.38), (x + 0.38, y-sub + 0.34), stroke: 1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.13))

      // White subtraction circle
      op-circle(x, y-sub, r-sub, [$-$], sz: 14pt)

      // Output down into 4-input adder tree
      line((x, y-sub - r-sub), (x, 6.2), stroke: 1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.13))
    }

    // ==========================================
    // 2. 4-INPUT ADDER TREE (UMN MAROON)
    // ==========================================
    rect((1.0, 5.45), (7.6, 6.2), stroke: 1.2pt + umn-maroon, fill: umn-maroon.lighten(92%))
    content((4.3, 5.825), text(size: 12pt, weight: "bold", fill: umn-maroon)[4-Input Adder Tree])

    // Direct connection into accumulation adder
    let x-acc = 4.3
    let y-acc = 4.15
    let r-acc = 0.45

    line((x-acc, 5.45), (x-acc, y-acc + r-acc), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.15))

    // ==========================================
    // 3. ACCUMULATION ADDER & 3-STAGE Acc. RING
    // ==========================================
    op-circle(x-acc, y-acc, r-acc, [$+$], sz: 14pt)

    let y-reg = 4.15
    let reg-xs = (6.1, 8.0, 9.9)

    // Adder -> first Acc. register
    line((x-acc + r-acc, y-acc), (reg-xs.at(0) - 0.65, y-reg), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.15))

    for idx in range(3) {
      let rx = reg-xs.at(idx)
      dff-box(rx, y-reg, 1.3, 0.95, [Acc.])

      if idx < 2 {
        let rx-next = reg-xs.at(idx + 1)
        line((rx + 0.65, y-reg), (rx-next - 0.65, y-reg), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.15))
      }
    }

    // Output tap from first Acc. -> SAD (with generous breathing room)
    let x-tap = 7.05
    circle((x-tap, y-reg), radius: 0.07, fill: umn-dark-gray)
    line((x-tap, y-reg), (x-tap, 5.2), (10.95, 5.2), stroke: 1.2pt + umn-dark-gray, mark: (end:
    "stealth", fill: umn-dark-gray, size: 0.01))
    content((11.1, 5.2), anchor: "west", text(size: 12pt, weight: "bold", fill: umn-dark-gray)[SAD])

    // ==========================================
    // 4. RIGHT-SIDE CLEAR MUX & FEEDBACK LOOP
    // ==========================================
    let x-mux = 9.9
    let y-mux = 2.25
    mux-right-to-left(x-mux, y-mux, 0.55, 1.2, 0.75)

    // Feedback from 3rd Acc. register into top-right port of MUX (clear = 0)
    line(
      (reg-xs.at(2) + 0.65, y-reg),
      (10.85, y-reg),
      (10.85, y-mux + 0.3),
      (x-mux + 0.275, y-mux + 0.3),
      stroke: 1.1pt + umn-dark-gray,
      mark: (end: "stealth", fill: umn-dark-gray, size: 0.14),
    )

    // 0 constant into bottom-right port of MUX (clear = 1)
    line((10.85, y-mux - 0.3), (x-mux + 0.275, y-mux - 0.3), stroke: 1.1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.14))
    content((10.98, y-mux - 0.3), anchor: "west", text(size: 11.5pt, weight: "bold", fill: umn-dark-gray)[0])

    // clear select line into bottom of MUX
    line((x-mux, y-mux - 0.95), (x-mux, y-mux - 0.48), stroke: 1pt + umn-dark-gray, mark: (end: "stealth", fill: umn-dark-gray, size: 0.13))
    content((x-mux, y-mux - 1.15), text(size: 11pt, weight: "bold", fill: umn-dark-gray)[clear])

    // MUX output (left) -> bottom of accumulation adder (no wire crossings!)
    line(
      (x-mux - 0.275, y-mux),
      (x-acc, y-mux),
      (x-acc, y-acc - r-acc),
      stroke: 1.1pt + umn-dark-gray,
      mark: (end: "stealth", fill: umn-dark-gray, size: 0.15),
    )

    // ==========================================
    // 5. STRIDED OUTPUT SECTION (MULTIPLE CYCLES)
    // ==========================================
    let y-base = 0
    let sz = 0.42
    let x-start = 1.0
    let num-elems = 24

    content((2.27, 0.65), anchor: "east", text(size: 11.5pt, fill: umn-dark-gray)[*Contiguous*])
    // Row 0: Contiguous row (touching side-by-side)
    for i in range(num-elems) {
      let x = x-start + i * sz
      rect((x, y-base), (x + sz, y-base + sz), stroke: 1.1pt + umn-maroon, fill: umn-maroon.lighten(92%))
    }

    // Strided output rows across multiple cycles (stride of 4 with increasing offsets: 0, 1, 2, 3)
    content((1.6, -0.25), anchor: "east", text(size: 11.5pt, fill: umn-dark-gray)[*Strided*])
    for t in range(4) {
      let ry = y-base - 0.5 - (t + 1) * sz
      let i = t
      while i < num-elems {
        let rx = x-start + i * sz
        rect((rx, ry), (rx + sz, ry + sz), stroke: 1.1pt + umn-maroon, fill: umn-maroon.lighten(92%))
        i += 4
      }
    }
  })
]

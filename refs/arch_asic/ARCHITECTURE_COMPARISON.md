# Motion Estimation Architecture Comparison

Comparison of the ME architectures in `refs/arch_asic/` (ASIC-focused) and `refs/fpga/` (FPGA-focused), plus a cross-folder comparison between the two groups.

## Papers

| Folder | File | Paper | Algorithm | Distortion metric |
|---|---|---|---|---|
| arch_asic | `asic_ds.pdf` | Chatterjee & Chakrabarti, *Low Power VLSI Architectures for One Bit Transformation Based Fast Motion Estimation*, IEEE Trans. Consumer Electronics 56(4), Nov 2010 | Diamond search on 1-bit transformed frames (FBS + VBS) | NNMP (XOR count on 1-bit frames) |
| arch_asic | `motion_estimator.pdf` | Wang, Peng & Tsai, *VLSI Architecture Design of Motion Estimator and In-Loop Filter for MPEG-4 AVC/H.264 Encoders*, IEEE 2004, pp. 148–152 | Hierarchical 16×16 ME (TWSS+TSS, "RSME") + fast partition decision + in-loop deblocking filter | SAD (8-bit) |
| fpga | `ds_impl.pdf` | Hegde & Vijay, *An Efficient Hardware Realization of Diamond Search Algorithm for Motion Estimation Task in Video Compression Applications*, IEEE 2017 | Classical DS (LDSP/SDSP) | SAD (8-bit) |
| fpga | `hwmds.pdf` | Ndili & Ogunfunmi, *Algorithm and Architecture Co-Design of Hardware-Oriented, Modified Diamond Search for Fast Motion Estimation in H.264/AVC*, IEEE TCSVT 21(9), 2011 | HMDS: modified diamond + 2× LDSP, fixed 3 steps | SAD (8-bit) |

## Note on the ASIC/FPGA distinction

None of the four papers is a taped-out production ASIC, so the folder split is by *design intent*, not by fabrication:

- `asic_ds.pdf` — synthesized on Xilinx FPGA, but designed for the low-power VLSI/ASIC design space (battery-powered portable video); targets SDTV.
- `motion_estimator.pdf` — HW/SW co-design prototype on an ARM9 + Xilinx FPGA platform (ARM Integrator).
- `ds_impl.pdf` — Virtex-4 FPGA prototype **and** a 90 nm standard-cell ASIC synthesis (Synopsys Design Compiler); the only paper with real ASIC area/power numbers.
- `hwmds.pdf` — FPSoC prototype (PowerPC + logic on Virtex-II Pro), with an explicit comparison table against ASIC-implemented architectures.

Cross-folder numbers must therefore be read with platform, voltage, and process in mind; direct apples-to-apples comparisons are limited (see §4).

---

## 1. Architectures in `refs/arch_asic/`

### 1.1 `asic_ds.pdf` — DS on 1-BT frames (Chatterjee & Chakrabarti)

**Algorithm.** DS applied to one-bit transformed (1-BT) binary frames. Each 8-bit frame is converted to 1 bit/pixel (MF-1BT multiplication-free kernel, shift-based filtering); matching criterion is NNMP (number of non-matching points, counted via XOR) instead of SAD. PSNR loss vs FS-on-1-BT is < 0.5 dB (0.08–0.48 dB across Hall Monitor / Foreman / Football / Tennis / Coastguard). DS needs 13.3–20.0 average search points/MB at ±16 vs 16.5–26.8 for 4-SS and 17.5–30.2 for NTSS.

**Architecture (FBS variant).**
- 9 PEs in parallel — one per LDSP candidate point; all 9 points evaluated simultaneously each step.
- PE: two 8-bit XOR arrays over 16-bit pixel vectors, two 256-entry LUTs (popcount), 4-bit adder, 9-bit accumulator; one 16×16 MB NNMP per 16 cycles.
- Search window: 48×48 bits (1-bit pixels, ±16 range) in **8 interleaved RAMs** (2304 bits total); the SW is preloaded before the MB's search.
- Current block: 16×16-bit register array — CB pixels read from external memory **once** and reused for the whole search.
- Search pixels: 5×48-bit register array plus 16-bit data selectors that feed the right 16-bit slice to each PE each step.
- Row-overlap data flow: the 9 candidate points share search rows (a full first row of the 9 points comes from only 5 rows of the SW); in the paper's 4×4 example this cuts memory accesses from 36 (9×4) to 8 (5+1+1+1). This is **pixel-data reuse, not SAD caching** between iterations.
- Comparator: min NNMP + location index 0–8; process control unit = pattern analyzer (LDSP/SDSP decision, new center/points) + control sequence generator (small FSM).

**VBS variant.** 36 PEs (4 PE arrays × 9); each 4 PE computes a primitive 4×4 NNMP in 4 cycles; a two-stage pipelined merge (adders) accumulates the 16 4×4 values into 4×8, 8×4, 8×8, 16×8, 8×16, 16×16 — all 41 partitions of the MB. Merge adds 2 cycles.

**Timing/synthesis (Xilinx, same FPGA as the compared prior art).**
- 22 cycles per DS step (1 load + 16 NNMP + 2 merge + 1 compare + 1 pattern + 1 control); max 7 steps.
- FBS: 140 cycles/MB, 731 slices (1103 LUT), max 135 MHz. VBS: 154 cycles/MB, 1014 slices (1576 LUT), max 129 MHz.
- vs Akin et al. (FS-based): 256 PEs, 4608-bit SW mem, 282 cycles/MB, 4758/6782 slices; vs Celebi et al.: 16 PEs, 24064-bit SW mem, 1039 cycles/MB, 944 slices.
- For SDTV 1280x720@30 fps the required clock is only 16.63 MHz (3600 MB/frame x 30 x 154 = 16.6 MHz), power 59 mW vs 83/96 mW for the two prior arts.

**Target.** Low-power, battery-powered portable video; SDTV (1280×720) @ 30 fps at ~16.6 MHz.

### 1.2 `motion_estimator.pdf` — RSME for H.264 (Wang, Peng, Tsai)

**Algorithm.** Two reduced search dimensions for H.264:
- *Spatio-temporal:* hierarchical 16×16 ME across up to 3 reference frames; the best MV from the most recent reference frame becomes the initial search point for the next (older) frame with a significantly reduced window. Within each frame, RSME = TWSS (coarse, step 8) followed by a 3-step TSS refinement (steps 3, 2, 1), with reduced sample-pixel count in step 1 so the window can grow without quadratic hardware cost.
- *Partition mode:* run 16 4×4 MEs at integer precision (search space ±2); merge 4×4 → 4×8/8×4 → 8×8 → 16×8/8×16 → 16×16 where neighboring sub-block MVs are within a threshold (SAD + MV coding overhead), horizontal merges prioritized.
- Also includes a 1-D in-loop deblocking filter (4×4 edges, 6-tap, boundary-strength driven, 4 pixels loaded/cycle on the 32-bit bus).

**Architecture.**
- Frames in external SDRAM (up to 4 frames, Y/Cb/Cr separate); Y-only ME.
- Memory controller on EBUS (AHB protocol); 32-bit internal bus IBUS.
- Two internal search-window buffers (Mem A / Mem B) in a write/read pipeline across the 3 reference frames: while ref 1's 16×16 ME runs, SW(2) loads, then SW(3), then the 4×4 ME stage — load and compute overlap.
- PE array of 4×4 SAD units (16 parallel 4×4 SADs); search controller; ME info (MVs/SADs) stored to a <1.5 KB SRAM for the partition-merge decision.
- In-loop filter: input registers, boundary-strength table, clip table, 1-D filter, bilinear/6-tap interpolation for fractional MVs, output registers.

**Platform/results.** Prototype on ARM Integrator (ARM9 core + Xilinx FPGA logic module); APB register file lets the ARM core configure the HW accelerator; 128 MB SDRAM. CIF 352×288 @ 15 fps, 3 reference frames, 32×32 SW, 50 MHz. FPGA: 4 KB block RAM for SW, 2781 LUTs for the SAD PE array, ~9700 LUTs estimated for ME + in-loop filter control logic.

**Quality.** RSME = full search (STEFAN: RSME slightly *better* PSNR than full search; FOREMAN: small loss) — "little or no degradation".

**Target.** H.264 encoder with multiple reference frames and full partition modes, real-time CIF @ 15 fps; HW/SW co-development flow.

### 1.3 Direct comparison: `asic_ds.pdf` vs `motion_estimator.pdf`

| Aspect | asic_ds (Chatterjee) | motion_estimator (Wang) |
|---|---|---|
| Metric | NNMP on 1-bit frames | SAD on 8-bit frames |
| Search algorithm | DS (LDSP/SDSP), variable iterations | TWSS + 3×TSS (RSME) + hierarchical 3-ref-frame |
| Parallelism model | 9 PEs, one per candidate point; all points in parallel per step | 16 parallel 4×4 SAD units per search step |
| Block sizes | 16×16 fixed; VBS via 36-PE merge tree | 16×16 hierarchical ME + 4×4-based fast partition decision (all H.264 sizes) |
| Reference frames | Single | Up to 3, with inter-frame MV prediction |
| On-chip SW memory | 2304 bits (1-bit SW, 48×48) | 4 KB block RAM (2 buffers) |
| Current block storage | Register array, read once | SRAM via EBUS/IBUS pipeline |
| Control | Small FSM (pattern analyzer + sequence generator) | Search controller + memory pipeline; ARM software for co-design |
| Timing per MB | 140 (FBS) / 154 (VBS) cycles | Not broken down per MB; 50 MHz system clock |
| Area (FPGA) | 731 / 1014 slices | 2781 LUT (PE) + ~9700 LUT (control, est.) |
| Max frequency | 135 / 129 MHz | 50 MHz (system) |
| Min required frequency | 16.63 MHz for SDTV 720p@30 | — (meets CIF@15 at 50 MHz) |
| Power | 59 mW (SDTV@30, low-freq op) | Not reported |
| Quality vs FS | <0.5 dB loss (1-bit metric caveat) | = no loss (slightly better on STEFAN) |
| Standard | MPEG-style MB (1-BT) | Full H.264 (incl. deblocking filter) |
| Extra modules | None | In-loop deblocking filter |

**Takeaways.**
- The two are complementary rather than competing: Chatterjee optimizes *power/area* with a 1-bit metric and a minimal FSM; Wang optimizes *standard coverage* (multi-ref, all partition modes, deblocking) at the cost of more control logic and an ARM/FPGA split.
- Chatterjee's parallelism is point-parallel (9 PEs = 9 candidates); Wang's is sub-block-parallel (16 × 4×4 SADs per candidate) — the same idea that appears in both FPGA papers.
- Both avoid inter-iteration SAD caching: Chatterjee reuses *pixel data* (row overlap + one-read register array); Wang reuses *loaded reference data* (2-bank SW pipeline) and *sub-block SADs* (4×4 SADs feed the partition-merge decision).
- The 1-bit metric is Chatterjee's biggest lever (2304-bit SW vs 4 KB; ~16 MHz for 720p), at the price of a ~0.1–0.5 dB quality penalty and no fractional-pel support.

---

## 2. Architectures in `refs/fpga/`

### 2.1 `ds_impl.pdf` — DS with adder-compressor PUs (Hegde & Vijay)

**Algorithm.** Classical DS: LDSP (9 points, pixel distance 2) repeated until the minimum SAD is at the center, then SDSP (5 points, distance 1). SAD metric on 8-bit pixels, 8×8 blocks (64 |differences|); 14-bit SAD register (max 256×64 = 16384); out-of-boundary candidate blocks are assigned the maximum SAD value. At search window ±7 (QCIF), average computations: DS 12.7–18.4 vs TSS =23 vs FS =204–207. PSNR = FS (Caltrain 27.219 vs 27.396; Misa 37.064 vs 37.125; Gess 35.423 vs 35.432).

**Architecture.**
- **9 processing modules (PMs)**, one per LDSP candidate block, all evaluated in parallel; comparator finds the minimum of the nine 14-bit SADs and passes the candidate index to the control unit (index 0 = center → set SDSP flag and evaluate 4 more candidate blocks; otherwise new LDSP centered at the minimum).
- PU datapath built from **3:2 and 5:2 adder compressors**: the 3:2 ACU (a full adder, 3 in / 2 out) handles three absolute differences; its outputs feed the 5:2 ACU (7 in / 2 out), summing all eight operands. This removes two adder columns vs an adder tree, saves one clock cycle vs a 4:2-compressor PU, and saves four XOR gates vs 8:2 — lower area and higher frequency.
- Address generation: base + reference address generators producing 16-bit addresses in a mesh pattern; block address generator raster-scans from the top-left pixel of the 8×8 block.
- Local memory only: 64-byte current-block memory, 256-byte candidate-block memory; frame data lives in external frame memory.
- No VBS support (fixed 8×8); single reference frame.

**Synthesis.**
- FPGA (Xilinx Virtex-4 xc4vlx15): 1597 slices, 3423 4-input LUTs, 1834 FFs, max 218.21 MHz (4.582 ns) — better than the compared Porto architecture (2007 slices, 213.3 MHz).
- ASIC (Synopsys Design Compiler, 90 nm standard cells): total cell area 28974 µm², total area 31175 µm² (16607 combinational + 12367 non-combinational + 2201 interconnect), power 137.53 µW (table header units are µW).
- Claims HD-compatible throughput at low hardware cost (QCIF in the reported simulations).

**Target.** High-throughput DS ME for (HD) video coding, optimized SAD datapath via adder compressors.

### 2.2 `hwmds.pdf` — HMDS co-design (Ndili & Ogunfunmi)

**Algorithm.** Hardware-oriented Modified Diamond Search:
- Step 1: a *modified diamond* whose outermost ("satellite") points sit on the search-range boundaries — captures large motion.
- Steps 2–3: standard LDSP refinement. Fixed 3-step termination: 41 search points total (36 unique; 5 repeated in the last step), constant O(1) complexity independent of search range — unlike FS O(s²) or SUMH O(6s).
- H.264/AVC features: zero + spatial-median MV predictors, all seven inter-prediction block sizes (16×16 … 4×4).
- Quality: Y-PSNR loss vs full search only 0.0018–0.0283 dB; bitrate change -0.16%…+1.85%; 71.0–97.6% ME time savings vs FS; 643 MOPS vs 17103 for FS at CIF/30 Hz (96% less).

**Architecture (algorithm-architecture co-designed).**
- **4 PUs in parallel, each with 16 PEs in a 1-D array**; each PE computes |a-b| for one pixel pair. Four PEs produce one column of a 4×4 SAD per cycle → a 4×4 SAD in 4 cycles → 16 4×4 SADs per candidate MB in 16 cycles. Four PUs process **4 candidate MBs simultaneously** (one current MB searched by 4 parallel units).
- **SAD combination trees** (one per PU): combine the 16 4×4 SADs in 5 cycles into the 41 SADs for all block sizes (1 16×16, 2 16×8, 2 8×16, 4 8×8, 8 8×4, 8 4×8, 16 4×4). This is hierarchical *within a step* (4×4 → larger sizes), not caching between iterations.
- **Comparison unit**: 41 comparing elements, each comparing the 4 SADs of one block size from the 4 PUs; min SAD in 4 cycles.
- **Memory**: two ping-pong SW banks (8 16×16 BRAMs each; 4 candidate MBs per bank; 1024 B/bank, 2048 B total) with a switch-box mux — load one bank while computing on the other. CMB in BRAM. 64-bit loads/cycle; 128 cycles/pass, 1280 cycles/CMB load.
- **Fixed schedule**: 10 search passes regardless of search range s → 27 cycles/pass (1 AGU + 1 memory read + 16 PU + 5 SAD tree + 4 comparison) → **270 cycles per CMB**. Min required frequency 16.04 MHz for CIF@30 with ±16 and 5 reference frames.
- SW memory 2048 B vs 2304 B for FS with level-A/B data reuse → 11% on-chip saving *without* any data-reuse scheme, because only 41 locations are searched (computation per CMB = 0.04× FS).
- FPSoC: PowerPC hard-core on Virtex-II Pro XC2VP30 (XUPV2P board) as controller — it handles MV predictors, mode decision (J = SAD + lR cost), address-range setup; the ME IP core does the SAD work. PLB 64-bit, DDR SDRAM frames, BRAM FIFOs with 64-bit burst transfers.

**Synthesis (Xilinx ISE 9.1, Virtex-II Pro, 130 nm).** 7.8K slices, 11.3K FFs, 10.8K 4-input LUTs, 268K equivalent gates, 144 16×8-bit dual-port RAMs, max 246.5 MHz, 25 mW (post-implementation XPower; 492 mW pre-implementation estimate), 461 frames/s throughput at QCIF.

**Comparisons in the paper.**
- vs FPSoCs: Qiu ACQPPS 3.9K slices/60 MHz/120 fps/551 mW; Canals FS 12.5K/100/146/841; Rahman 14.5K/149.2/150/965; Roma 14.7K/76.1/1127; their own Modified SUMH 11.4K/145.2/180/492. HMDS wins on max frequency, throughput, and power; second-lowest area.
- vs ASICs: Chao DS (0.35 µm, 301K transistors, 50 MHz, 223.6 mW), Miyakoshi gradient descent (0.18 µm, 1000K, 13.5 MHz, 6.56 mW), Lin 4SS (546K, 48.67 MHz, 8.46 mW), Chen single-iteration 4SS (708K, 66 MHz, 2.13 mW). HMDS claims ASIC-comparable power (25 mW at 2.5 V) with the lowest transistor count among those listed — presented as an indication of ASIC portability, not a like-for-like measurement.

**Target.** H.264/AVC baseline profile level 1–2 (QCIF–SIF @ 30 Hz, up to 5–6 reference frames), low-power mobile devices; also tested 720p@60.

---

## 3. Cross-folder comparison: ASIC-focused vs FPGA architectures

### 3.1 Side-by-side

| Aspect | asic_ds (arch_asic) | motion_estimator (arch_asic) | ds_impl (fpga) | hwmds (fpga) |
|---|---|---|---|---|
| Algorithm | DS (LDSP/SDSP) | TWSS+TSS (RSME), 3-ref hierarchical | DS (LDSP/SDSP) | HMDS (mod. diamond + 2×LDSP, fixed 3 steps) |
| Iteration count | Variable (<=7 in tests) | Fixed 2-stage | Variable (LDSP loop) | Fixed (10 passes, 41 points) |
| Metric | NNMP (1-bit) | SAD (8-bit) | SAD (8-bit) | SAD (8-bit) |
| Parallelism | 9 PEs (1/candidate point) | 16 × 4×4 SAD units | 9 PMs (1/candidate point) | 4 PUs × 16 PEs (4 MBs in parallel) |
| Block sizes | 16×16; 41-partition VBS | 16×16 ME + fast 4×4-based partition decision | 8×8 fixed | All H.264 inter sizes (VBS tree) |
| Reference frames | 1 | 3 (hierarchical) | 1 | Tested to 5 |
| SW on-chip memory | 2304 bits (1-bit) | 4 KB (2 buffers) | 64+256 B local (frames external) | 2048 B (2 ping-pong banks) |
| Data reuse | Pixel rows shared across candidates; CB read once | 2-bank SW pipeline; 4×4 SADs feed merge | None beyond local registers | Ping-pong load/compute; 4×4→16×16 SAD accumulation |
| Control | Small FSM (pattern analyzer + sequence gen.) | Search controller + mem pipeline + ARM SW | Control unit + address generators | Fixed 10-pass schedule + PowerPC for predictors/mode |
| Timing/MB | 140 / 154 cycles | — | — | 270 cycles (10 × 27) |
| FPGA area | 731 / 1014 slices | 2781 LUT + ~9700 LUT (est.) | 1597 slices (3423 LUT) | 7.8K slices (10.8K LUT, 268K gates) |
| ASIC area | — (FPGA only) | — (FPGA only) | 31175 µm² @ 90 nm | — (compared vs ASIC tables) |
| Max frequency | 135 / 129 MHz | 50 MHz (system) | 218.21 MHz | 246.5 MHz |
| Min required frequency | 16.63 MHz (SDTV 720p@30) | — | — | 16.04 MHz (CIF@30, 5 refs) |
| Power | 59 mW (SDTV@30) | — | 137.53 µW @ 90 nm (ASIC est.) | 25 mW (FPGA, QCIF) |
| Quality vs FS | <0.5 dB (1-bit caveat) | =0 (slightly better on STEFAN) | =0.1–0.2 dB | 0.002–0.028 dB |
| Throughput target | 1280×720@30 | CIF@15 | QCIF (HD claimed) | QCIF@461 fps; CIF real-time, 5 refs |

### 3.2 What separates the two groups

**Design intent.** The `arch_asic` papers are organized around *algorithm reduction for a fixed function*: Chatterjee minimizes clock frequency and power for battery operation (1-bit datapath, tiny FSM, <=1014 slices); Wang covers the full H.264 ME + deblocking problem with a hardware accelerator steered by an ARM core. The `fpga` papers are organized around *prototyping throughput*: ds_impl pushes max frequency (218 MHz) and SAD datapath efficiency (3:2/5:2 compressors); hwmds co-designs a fixed-iteration algorithm with a 4-way parallel, 10-pass regular schedule and an embedded PowerPC for the irregular parts (predictors, RDO mode decision).

**Iteration regularity (the key hardware driver).**
- Classical DS (asic_ds, ds_impl) has a *variable* number of LDSP iterations → needs a pattern analyzer that computes new centers/points, and worst-case latency is unpredictable (7 steps observed).
- HMDS (hwmds) fixes the search at 3 steps / 10 passes / 41 points → constant 270 cycles/MB, O(1) in search range, no pattern analysis — the reason it can use a plain fixed schedule and still beat DS in measured speedup only slightly.
- Wang's RSME is also fixed-structure (coarse TWSS + 3 TSS stages), trading adaptivity for pipeline regularity.
This matches the corrected understanding of DS hardware: the speedups of DS-style algorithms come from *search-pattern design* (fewer candidate points, center bias), not from reusing previously computed SAD values; none of the four architectures caches SADs across iterations.

**Parallelism styles.**
- *Point-parallel*: one PE/PM per candidate point (9 units for LDSP) — asic_ds and ds_impl. Simple control, all candidates scored per step; idle PEs during SDSP (5 of 9 points) are a known cost.
- *Row-parallel / sub-block-parallel*: PEs compute pixel pairs streamed per row, with a tree accumulating 4×4 → larger block SADs — hwmds and motion_estimator. Better PE utilization and built-in VBS support, more control for address generation.
- asic_ds combines point-parallel PEs with a row-overlap *memory* scheme (5 rows serve 9 candidates), which is where its power savings come from.

**Memory organization.**
- asic_ds: smallest on-chip footprint overall (2304 *bits*) thanks to 1-bit pixels; CB held in registers, never re-read.
- hwmds: ping-pong banks decouple loading from computing; 2048 B SW beats FS-with-reuse (2304 B) purely because the search space is 41 points, not 1089.
- ds_impl: keeps only 320 B on chip (current + one candidate block), streaming from frame memory — minimal memory, but no pipelining reported between load and compute.
- motion_estimator: the only one that explicitly pipelines *multiple reference frames* (SW(1) computes while SW(2), SW(3) load), at the cost of two 4 KB buffers.

**Control complexity.**
- Lightest: ds_impl (comparator + control unit + address generators) and asic_ds (pattern analyzer + sequence generator FSM).
- Mid: motion_estimator (search controller + memory pipeline controller; ARM handles the rest).
- Heaviest but *software-assisted*: hwmds offloads predictors, J-cost/mode decision, and memory management to the on-chip PowerPC, keeping the datapath IP small and the schedule static.

**Power and area (with caveats).**
- The lowest reported power is ds_impl's 137.53 µW — but that is a 90 nm standard-cell *estimate* at QCIF-scale activity, not an FPGA measurement.
- hwmds (25 mW FPGA, 268K gates) and asic_ds (59 mW at SDTV, ~1.5K LUTs) are the most credible low-power datapaths; asic_ds reaches 720p@30 at only 16.63 MHz, which is the strongest "low frequency => low power" result of the four.
- Area ordering (roughly, despite different FPGAs): asic_ds (<=1014 slices) < ds_impl (1597) < motion_estimator (~12.5K LUT est.) < hwmds (7.8K slices / 268K gates, largest because it searches 4 MBs in parallel with full VBS).
- Frequency ordering: hwmds 246.5 > ds_impl 218.2 > asic_ds 135/129 > motion_estimator 50 MHz — hwmds and ds_impl exploit modern synthesis (compressor-based datapath, 130/15 nm-class parts), while asic_ds intentionally accepts lower fmax in exchange for power.

**Standards coverage.** Only hwmds and motion_estimator are complete H.264/AVC ME designs (VBS, predictors, multi-ref; motion_estimator also deblocking). asic_ds is MPEG-style 16×16 with an add-on VBS tree (41 partitions, but no H.264 predictors/RDO). ds_impl is a fixed 8×8 SAD block with no VBS or multi-reference — the simplest datapath of the four.

### 3.3 Implications for an ASIC-focused design

1. **Fix the iteration count.** If targeting ASIC regularity, HMDS-style fixed steps (or Wang-style two-stage) remove the pattern-analyzer FSM and make latency worst-case-bounded; the DS literature's variable LDSP loop is the main source of control complexity.
2. **Point-parallel is enough for 16×16-only.** Nine PEs scoring the LDSP simultaneously is simpler than the 4-PU row-parallel fabric, and pairs well with 1-bit/NNMP datapaths (asic_ds) or compressor-based SADs (ds_impl). Add a SAD accumulation tree only if VBS is required.
3. **Memory is the power term.** The consistent winner is keeping the SW (and CB) on-chip and never re-reading from external memory mid-search: asic_ds (one CB read, row overlap) and hwmds (ping-pong banks, 128-cycle loads) both derive their low-power numbers from memory behavior, not from datapath cleverness.
4. **No inter-iteration SAD caching.** None of these designs pays for a SAD-result cache; the per-step SAD/NNMP accumulation (4×4 → 16×16 trees) is the only "reuse" that shows up, and it is intra-step. Keep the controller to center/point arithmetic and a min-plus comparator.
5. **Power targets set the clock.** asic_ds shows a 720p-class encoder ME can run at ~16 MHz (59 mW); hwmds needs 16.04 MHz minimum for CIF with 5 reference frames. A battery-oriented ASIC design should size its PE count to the min-frequency budget rather than chasing fmax (the ds_impl/hwmds 200+ MHz numbers are prototyping headroom, not a design goal for low power).

## 4. Caveats

- **Different platforms and metrics.** Power/area numbers span Xilinx Virtex-4 / Virtex-II Pro / ISE-era synthesis, a 90 nm standard-cell estimate, and an ARM+FPGA co-design at 50 MHz. The 1-bit NNMP metric (asic_ds) is not quality-comparable with 8-bit SAD results.
- **Different workloads.** 720p@30 (asic_ds), CIF@15 (motion_estimator), QCIF@±7 (ds_impl), CIF@30 with 5 refs (hwmds) — throughput and min-frequency figures cannot be transposed across them.
- **ASIC vs FPGA labels.** Per the "Note on the ASIC/FPGA distinction" section, none is a taped-out ASIC; ds_impl's 90 nm numbers and hwmds' ASIC comparison table are the only ASIC-side data points, and both are estimates/indirect comparisons.
- **Reported-number quirks.** ds_impl's power table prints "137.53W" but the header unit is µW; hwmds reports both a pre-implementation (492 mW) and post-implementation (25 mW) power figure; asic_ds' FBS/VBS slice counts are on different comparison FPGAs for its prior-art table.

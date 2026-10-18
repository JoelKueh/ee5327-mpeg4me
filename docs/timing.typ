
= 720x1280p

- 45 blocks tall, 80 blocks wide, total of 3600 blocks
- 3 cycles split like so (test a total of 37 candidate points per reference block)
  1. First use the 17-point modified start
  2. Then use the 12-point LDSP
  3. Then use LDSP with only having to recompute 8 points.
- If you have extra clocks, add more reference points/frames
- HWMDS paper takes 27 clock cycles to test a reference block.


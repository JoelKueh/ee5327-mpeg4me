
= Full Search Architecture

```
Reference Block                     Current Block
 1 | 1 1 1 1  2 2 2 2  3 3 3 3       1 | x x x x
 2 | 1 1 1 1  2 2 2 2  3 3 3 3       2 | x x x x
 3 | 1 1 1 1  2 2 2 2  3 3 3 3       3 | x x x x
 4 | 1 1 1 1  2 2 2 2  3 3 3 3       4 | x x x x
   |                            
 5 | 4 4 4 4  5 5 5 5  6 6 6 6  
 6 | 4 4 4 4  5 5 5 5  6 6 6 6  
 7 | 4 4 4 4  5 5 5 5  6 6 6 6  
 8 | 4 4 4 4  5 5 5 5  6 6 6 6  
   |                            
 9 | 7 7 7 7  8 8 8 8  9 9 9 9  
10 | 7 7 7 7  8 8 8 8  9 9 9 9  
11 | 7 7 7 7  8 8 8 8  9 9 9 9  
12 | 7 7 7 7  8 8 8 8  9 9 9 9   
```

For full SAD computation, row 1 of the reference block must be paired with every
row of the current block. First match with the first 3 columns of the reference block.

```
C(0:3, 0)
C(0:3, 1)
C(0:3, 2)
C(0:3, 3)
C(0:3, 4)
...
```

Look at the top left corner of the reference block ($4 times 4$). With a search window of $32 times
32$, it must be compared with $32 times 32$ different things. Set L to the width fo your search
window so that you can compute L different $4 times 4$ SADs over 4 clock cycles as the candidate
block is streamed in through an accumulator.

In the first 4 cycles, C(0:3, 0) is compared with $L times 4$ different blocks. After L cycles
C(0:3, 0) is compared with $L times L$ different blocks. You must do this once for each of the
$L - 3$ different search windows in your block.

$ "Cycles per Block" = L times L - 3 $

You need a total of L - 3 PE arrays to process the whole block at once. Additionally, your height
has to be the width of the entire search window.


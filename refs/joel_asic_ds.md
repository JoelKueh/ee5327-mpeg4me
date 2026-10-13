
# Low Power VLSI Architectures for One Bit Transformation Based Fast Motion Estimation

## Summary

- Fixed block size and variable block size (VBS) motion estimation (ME) algorithm implementations
- One-bit transformed (1-BT) image frames
- Perform Diamond Search on 1-BT image frames.
- Usually done using FS algorithm
- Using DS reduces computational complexity and can reduce power consumption.
- Targets SDTV (1280x720 @ 30fps)
- Motion Estimation takes 80% of the total computational power of the block decoder

## Architecture Overview

- Uses Boolean XOR on top of a 1-bit transform for NNMP (non-matching points) instead of SAD.
- Image is filtered over a multi band-pass filter
    - This is done by convolution with a kernel
    - If the filtered frame is "darker" than the old frame, then set the bit.

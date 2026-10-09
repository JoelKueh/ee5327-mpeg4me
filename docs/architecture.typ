
= EE5327: mpeg4me Architecture

// NOTES:
//
// - Current and reference frames are stored in off-chip memory
// - Current MB (CMB) and Search Window (SW)

== Overview

This repository implements the Diamond Search (DS) algorithm for Motion Estimation (ME) in MPEG4.
It is meant to be slotted in to a motion estimation flow.

== Architecture

A good architecture must balance memory bandwidth with computation speed. One option would be to
use some sort of swap buffer that is being filled with new pixel data while computation is being
performed on the old pixel data.

=== Parallel Sum of Absolute Difference Engines

=== Current / Reference Frame Memory

// NOTES:
//
// - Stored in off-chip memory

=== Search Window Memory

// NOTES:
//
// - 

=== Control Module

=== Current 


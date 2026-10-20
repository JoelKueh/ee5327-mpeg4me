1. Mukherjee, Mahajan, Dhar, Chakrabarti (2016) — "High Performance VLSI Design of Diamond Search Algorithm for Fast Motion Estimation" — J. of Circuits, Systems & Computers (World Scientific), DOI: 10.1142/S0218126616501140. Pure LDSP/SDSP DS VLSI design — your pick.
2. Ndili, Muralidhar, Ogunfunmi (2011) — "Algorithm and Architecture Co-Design of Hardware-Oriented, Modified Diamond Search for Fast Motion Estimation in H.264/AVC" — IEEE TCSVT, doc 5740316. This is your refs/hwmds.pdf — the baseline you already hold; good for cross-comparison.
3. Srivastava, Muralidhar, Rama Rao (2014) — "A High Throughput Diamond Search Architecture with Shift Mechanism for 720p Motion Estimation" — IEEE ICDCCom, doc 7024688. Subsampled DS + shift mechanism, with synthesis results. Same UCF group as #2 — the most directly comparable pair.
4. Chatterjee & Chakrabarti (2010) — "Low Power VLSI Architectures for One Bit Transformation Based Fast Motion Estimation" — IEEE Trans. Consumer Electronics, doc 5681153. Pure DS (LDSP/SDSP), low-power ASIC-oriented design.
5. Porto, Agostini, Bampi, Susin (2008) — "A High Throughput and Low Cost Diamond Search Architecture for HDTV Motion Estimation" — IEEE ICME, doc 4607614. LDSP/SDSP architecture, VHDL, Virtex-4 FPGA.
6. Gogoi & Peesapati (2021) — "Design and Implementation of an Efficient Multi-Pattern Motion Estimation Search Algorithm for HEVC/H.265" — IEEE Trans. Consumer Electronics, doc 9609085. 90 nm library, 353 MHz, 4K@60 real-time, 1.59 M gates — hard numbers for an ASIC-class baseline (diamond is one of its 
patterns).
7. Mukherjee, Vinod, Chakrabarti, Dutta (2020) — "Hexagon based Compressed Diamond Algorithm for Motion Estimation and its Dedicated VLSI System for HD Videos" — Expert Systems with Applications, link. Modified DS VLSI system.
8. Khemiri, Kibeya, Loukil, Sayadi, Atri (2018) — "Real-time Motion Estimation Diamond Search Algorithm for the New High Efficiency Video Coding on FPGA" — Integration, the VLSI Journal, 10.1007/s10470-017-1072-6.
9. Vittapu, Kundu, Chatterjee (2023) — "A New Low Complexity Bit-truncation Based Motion Estimation and Its Efficient VLSI Architecture" — IETE Journal of Research, 10.1080/03772063.2021.1965040. DS with bit-truncation, reduced external memory access.
10. Hegde & Vijay (2017) — "An Efficient Hardware Realization of Diamond Search Algorithm for Motion Estimation Task in Video Compression Applications" — ICMDCS 2017.

Secondary/adjacent (not pure DS or less verified):
- Elhamzi, Thavot, Dubois, Gorin, et al. (2011) — DS in CAL dataflow language, ICM 2011 (ST-Microelectronics co-design angle).
- Rajabai et al. (2018) — DS in Verilog, Synopsys DC 90 nm synthesis, Int. J. of Engineering and Technology.
- Vayalil, Paul, Kong (2017) — RNS hardware ME accelerator for HEVC using modified DS, IEEE TCSVT, doc 8239858.
- Lam (2005) — "An Efficient VLSI Architecture for Diamond-Search-Pattern-Based Motion Estimation Algorithms" — surfaced via Semantic Scholar but venue not verified; worth a quick check before citing.
- Kuhn (1999) — "Fast MPEG-4 Motion Estimation: Processor based and Flexible VLSI Implementations" — J. VLSI Signal Processing, link. The most MPEG-4-specific VLSI reference here; search algorithm not confirmed DS.

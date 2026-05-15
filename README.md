# PicoRISCV-SoC — RISC-V CPU + ML Accelerator SoC | ASAP7 7nm

**Author:** Rakshith Suresh  
**Affiliation:** MS Electrical Engineering  
University of Southern California, Viterbi School of Engineering  
**Email:** rsuresh@usc.edu | **GitHub:** [RakshithSuresh2001](https://github.com/RakshithSuresh2001)

---

## Overview

A fully custom **RISC-V SoC** integrating a **PicoRV32 RV32IMC CPU** with an **8×8 weight-stationary systolic array ML accelerator**, designed from scratch in SystemVerilog and taken through a complete **RTL-to-GDS physical design flow** using open-source EDA tools on ASAP7 7nm.

The CPU communicates with the accelerator via a custom **AXI-Lite slave register file** using memory-mapped I/O. Bare-metal C firmware (no libc) programs weights, feeds activations, and reads results back — all verified in simulation with a self-checking testbench.

This project demonstrates the full hardware-software stack: RTL design, functional verification, bare-metal firmware, physical design, and signoff on a real 7nm predictive process node.

---

## Physical Design Results (ASAP7 7nm — First Pass)

| Metric | Value |
|---|---|
| **Total cells** | 61,529 |
| **Chip area** | 7,564 µm² |
| **Sequential area** | 2,355 µm² (31%) |
| **WNS** | -1,265 ps |
| **TNS** | -2,731,396 ps |
| **Total power** | 42.1 W |
| **Leakage power** | 6.93 µW |
| **Flow runtime** | ~45 min |

> **Note on timing and power:** The first-pass run uses flip-flop arrays to implement SRAM, which inflates power and prevents timing closure. SRAM macro integration is planned for the next iteration to close timing and bring power to realistic levels. The flow demonstrates complete RTL-to-GDS on a real 7nm predictive process node end to end.

---

## Architecture

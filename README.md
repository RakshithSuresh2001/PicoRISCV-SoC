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

+-----------------------------------------------------+
|                    SoC -- ASAP7 7nm                 |
|                                                     |
|  +-------------+         memory bus                 |
|  |  PicoRV32   |-----------------------------+      |
|  |  RV32IMC    |                             |      |
|  |  500 MHz    |                             |      |
|  +-------------+                             |      |
|        |                                     |      |
|  +----------+  +----------+  +----------+   |      |
|  | ISRAM    |  | DSRAM    |  |  UART    |   |      |
|  | 64 KB    |  | 32 KB    |  | 115200   |   |      |
|  +----------+  +----------+  +----------+   |      |
|                                             |      |
|                         +-------------------+      |
|                         v                           |
|                +-----------------+                  |
|                | AXI-Lite slave  |                  |
|                | register file   |                  |
|                +--------+--------+                  |
|                         v                           |
|                +-----------------+                  |
|                | 8x8 Systolic    |                  |
|                | Array  64 PEs   |                  |
|                +-----------------+                  |
+-----------------------------------------------------+

### Memory Map

| Base address | Size | Block |
|---|---|---|
| `0x0000_0000` | 64 KB | Instruction SRAM |
| `0x0001_0000` | 32 KB | Data SRAM |
| `0x1000_0000` | 4 KB | Systolic array register file |
| `0x2000_0000` | 4 KB | UART |

### Systolic Array Register File (base `0x1000_0000`)

| Offset | Register | Description |
|---|---|---|
| `0x00` | `WEIGHT_ROW` | bits[2:0] = row index (0–7) |
| `0x04` | `WEIGHT_DATA_LO` | bits[31:0] = weight_data_flat[31:0] |
| `0x08` | `WEIGHT_DATA_HI` | bits[31:0] = weight_data_flat[63:32] |
| `0x0C` | `WEIGHT_LOAD` | write any value = pulse weight_load |
| `0x10` | `ACT_LO` | bits[31:0] = act_in_flat[31:0] |
| `0x14` | `ACT_HI` | bits[31:0] = act_in_flat[63:32] |
| `0x18` | `PSUM_SEL` | bits[2:0] = output column to read (0–7) |
| `0x1C` | `PSUM_DATA` | bits[31:0] = accumulated result (read-only) |

---

## CPU Configuration

| Parameter | Value |
|---|---|
| ISA | RV32IMC |
| Target clock | 500 MHz (ASAP7) |
| Instruction SRAM | 64 KB at `0x0000_0000` |
| Data SRAM | 32 KB at `0x0001_0000` |
| Stack pointer | `0x0001_7FFC` (top of DSRAM) |
| Reset vector | `0x0000_0000` |
| Hardware multiply | Enabled |
| Compressed ISA (RVC) | Enabled |
| IRQ lines | 16 (Phase 3) |

---

## Firmware Flow

The bare-metal C firmware (no libc, no OS) runs the following sequence:

1. Write sentinel `0xDEADBEEF` to DSRAM — confirms CPU booted and SRAM is writable
2. Load identity matrix row by row via `WEIGHT_ROW` + `WEIGHT_DATA_LO/HI` + `WEIGHT_LOAD`
3. Feed activation vector `[1,2,3,4,5,6,7,8]` via `ACT_LO/HI`
4. Wait for pipeline to drain (~20 cycles)
5. Read 8 outputs via `PSUM_SEL` + `PSUM_DATA` into DSRAM
6. Write completion flag `0x600DC0DE`

The testbench checks all flags and results directly from DSRAM — no UART dependency in simulation.

---

## Verification

The testbench (`tb_soc_top.sv`) is fully self-checking:

- Loads firmware hex directly into instruction SRAM
- Releases reset and monitors CPU boot
- Waits for firmware completion flag in DSRAM
- Checks sentinel, stack pointer, and all 8 systolic array outputs against expected values
[TB] Reset released
PASS [Test 1] CPU boot PC=0x00000044
INFO firmware completed OK
PASS [Test 3] DSRAM sentinel correct
PASS [Test 4] Stack sp=0x00017fec
PASS [Test 5] SA all 8 outputs correct
[TB] All tests complete

Expected result: identity matrix × [1,2,3,4,5,6,7,8] = [1,2,3,4,5,6,7,8] across all 8 output columns.

---

## Tool Flow
SystemVerilog RTL + C firmware
|
v
+---------+
|  Yosys  |  Logic synthesis -> standard cells
|  Synth  |  Liberty frontend + ABC optimization
+----+----+
|  gate-level netlist
v
+--------------------------------------------------+
|                  OpenROAD v2.0                   |
|  +----------+  +-------+  +-----+  +--------+   |
|  | Floorplan|->| Place |->| CTS |->| Route  |   |
|  | PDN, IOs |  | GP+DP |  |     |  | GR+DR  |   |
|  +----------+  +-------+  +-----+  +--------+   |
+----+---------------------------------------------+
|  routed DEF + ODB + SPEF
v
+---------+
| KLayout |  GDS merge -> 6_final.gds
+---------+

### Flow Steps and Runtime

| Step | Description | Time |
|---|---|---|
| 1_1 | Yosys canonicalize | 0s |
| 1_2 | Yosys synthesis | 59s |
| 2_x | Floorplan (core, PDN, tapcells) | ~108s |
| 3_x | Placement (global + detail) | ~180s |
| 4_1 | Clock Tree Synthesis | 131s |
| 5_1 | Global routing | 398s |
| 5_2 | Detailed routing | 1709s |
| 5_3 | Fill cells | 2s |
| 6_x | Signoff + GDS merge | ~101s |
| **Total** | | **~45 min** |

---

## File Structure
PicoRISCV-SoC/
├── soc_top.sv          # Top-level: CPU, SRAM, address decoder, peripherals
├── axilite_slave.sv    # AXI-Lite register file for systolic array
├── systolic_array.sv   # 8x8 weight-stationary systolic array RTL
├── pe.sv               # Processing element
├── uart_tx.sv          # 8N1 UART transmitter (500 MHz, 115200 baud)
├── tb_soc_top.sv       # Self-checking testbench
├── test_firmware.c     # Bare-metal C firmware (no libc)
├── link.ld             # Linker script
├── config.mk           # OpenROAD ASAP7 flow configuration
├── constraint.sdc      # Timing constraints
└── pdn.tcl             # Custom power delivery network

---

## How to Run

### Dependencies
- `iverilog` (Icarus Verilog)
- `riscv64-unknown-elf-gcc`
- PicoRV32: `git clone https://github.com/YosysHQ/picorv32`
- OpenROAD flow scripts

### Simulation

```bash
# Compile firmware
riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -nostdlib \
    -ffreestanding -fno-builtin \
    -T link.ld test_firmware.c -o test_firmware.elf

riscv64-unknown-elf-objcopy -O verilog test_firmware.elf test_firmware.hex

# Convert to word-addressed hex
python3 convert_hex.py

# Simulate
iverilog -g2012 -o sim \
    tb_soc_top.sv soc_top.sv uart_tx.sv \
    axilite_slave.sv systolic_array.sv pe.sv \
    picorv32/picorv32.v

vvp sim +firmware=firmware.hex
```

### RTL-to-GDS Flow (ASAP7 7nm)

```bash
# Decompress liberty files (required)
cd OpenROAD-flow-scripts/flow/platforms/asap7/lib/NLDM
gunzip -k *.lib.gz

# Copy design files
cp soc_top.sv uart_tx.sv axilite_slave.sv systolic_array.sv pe.sv picorv32.v \
    OpenROAD-flow-scripts/flow/designs/asap7/picoriscv_soc/

# Run the flow
cd OpenROAD-flow-scripts/flow
make DESIGN_CONFIG=./designs/asap7/picoriscv_soc/config.mk
```

### Extract PPA Metrics

```bash
cd OpenROAD-flow-scripts/flow
openroad -no_init << 'EOF'
read_db results/asap7/soc_top/base/6_final.odb
read_liberty platforms/asap7/lib/NLDM/asap7sc7p5t_SIMPLE_RVT_FF_nldm_211120.lib
read_liberty platforms/asap7/lib/NLDM/asap7sc7p5t_SEQ_RVT_FF_nldm_220123.lib
read_liberty platforms/asap7/lib/NLDM/asap7sc7p5t_AO_RVT_FF_nldm_211120.lib
read_liberty platforms/asap7/lib/NLDM/asap7sc7p5t_OA_RVT_FF_nldm_211120.lib
read_liberty platforms/asap7/lib/NLDM/asap7sc7p5t_INVBUF_RVT_FF_nldm_220122.lib
read_sdc results/asap7/soc_top/base/6_final.sdc
report_wns
report_tns
report_power
EOF
```

---

## Key Challenges and Debugging

| Issue | Fix |
|---|---|
| SYNTH_MEMORY_MAX_BITS exceeded | Set `SYNTH_MEMORY_MAX_BITS=32768` in config.mk |
| FF-based SRAM inflating power and area | Reduced SRAM depth for first-pass run; SRAM macros planned |
| `sel_isram` blocking data loads from ISRAM | Removed `mem_instr` requirement from ISRAM address decode |
| CPU stalling on UART poll loop | Fixed `sel_uart` to use `!mem_instr` instead of `!mem_addr` |
| AXI-Lite slave double-gating `mem_valid` | Passed real `mem_valid` to slave instead of `sel_sa` |
| PDN IR drop catastrophic on first pass | Custom PDN copied from systolic array; SRAM macro integration needed for full fix |
| Firmware UART too slow for simulation | Removed UART from sim firmware; testbench reads DSRAM directly |

---

## Roadmap

- [x] Phase 1 — PicoRV32 + SRAM baseline, all tests passing
- [x] Phase 2 — Systolic array integration and verification
- [x] OpenROAD physical design on ASAP7 7nm (first pass)
- [ ] SRAM macro integration to close timing
- [ ] Phase 3 — SPI + interrupt-driven operation
- [ ] Updated PPA report post SRAM macro

---

## References

- [OpenROAD Project](https://github.com/The-OpenROAD-Project/OpenROAD)
- [OpenROAD Flow Scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts)
- [ASAP7 Predictive PDK](https://github.com/The-OpenROAD-Project/asap7)
- [PicoRV32 — A Size-Optimized RISC-V CPU](https://github.com/YosysHQ/picorv32)
- [Yosys Open Synthesis Suite](https://github.com/YosysHQ/yosys)
- Norman P. Jouppi et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit" (Google TPU paper)

---

*Implemented as part of MS EE independent project work at USC Viterbi School of Engineering, 2026.*

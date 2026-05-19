# PicoRISCV-SoC

A RISC-V SoC integrating a PicoRV32 CPU with an 8×8 systolic array ML accelerator, implemented in RTL and taken through full physical design on ASAP7 using OpenROAD.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                      soc_top                        │
│                                                     │
│  ┌─────────────┐     ┌──────────────────────────┐  │
│  │  PicoRV32   │     │   8×8 Systolic Array     │  │
│  │  RISC-V CPU │────▶│   (INT8 MAC, INT32 acc)  │  │
│  └──────┬──────┘     └──────────────────────────┘  │
│         │ Memory Bus        ▲            ▲          │
│  ┌──────▼──────┐     ┌──────┴──┐  ┌─────┴──────┐  │
│  │  AXI-Lite   │     │  ISRAM  │  │   DSRAM    │  │
│  │  Slave      │     │ 256×32  │  │  256×32    │  │
│  └─────────────┘     │(Fakeram)│  │ (Fakeram)  │  │
│  ┌─────────────┐     └─────────┘  └────────────┘  │
│  │  SPI Slave  │                                    │
│  │  (Phase 3)  │     ┌──────────────────────────┐  │
│  └─────────────┘     │       UART TX            │  │
│                       └──────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Features

- **CPU**: PicoRV32 RISC-V (RV32IM) — hardware multiply, software divide
- **ML Accelerator**: 8×8 systolic array, INT8 weights, INT32 accumulators
- **Memory**: 2× Fakeram 256×32 SRAM macros (instruction + data, 1KB each)
- **Peripherals**: AXI-Lite MMIO, SPI slave, UART TX
- **Interrupts**: IRQ line from systolic array done signal to CPU irq[0]
- **Interface**: SPI slave gives direct access to systolic array (390 → 4 pins)

## Development Phases

| Phase | Feature | Status |
|-------|---------|--------|
| 1 | PicoRV32 CPU + SRAM baseline | ✅ Complete |
| 2 | Systolic array + AXI-Lite MMIO | ✅ Complete |
| 3 | SPI slave + IRQ done signal | ✅ Complete |

## Physical Design — ASAP7 (OpenROAD)

| Metric | Value |
|--------|-------|
| Technology | ASAP7 7nm FinFET (academic PDK) |
| Clock Frequency | 500 MHz |
| Total Cells | 47,051 |
| Logic Area | 5,431 µm² |
| SRAM Macros | 2× Fakeram7 256×32 (Fakeram) |
| Sequential Elements | 28.19% (5,251 FFs) |
| WNS | −694 ps (picorv32 ALU path) |
| Total Power | ~10 W @ 50% toggle rate (pre-silicon estimate) |
| DRC Violations | 0 |

> **Note on power**: The 10W figure uses the standard 50% toggle rate assumption, which is pessimistic for a CPU-based design. At a realistic 10% activity factor the estimated power is ~2W. Gate-level simulation with representative workloads would give a more accurate number.

## Systolic Array — Cross-Node Comparison

| Metric | Sky130 (180nm) | ASAP7 (7nm) | Improvement |
|--------|---------------|-------------|-------------|
| Frequency | 50 MHz | 500 MHz | 10× |
| Area | 251,970 µm² | 3,903 µm² | 64.6× |
| Leakage Power | — | 3.58 µW | — |
| Cells | 25,030 | 32,446 | — |

## Simulation

All simulation tests passing:

- **Systolic array**: 80/80 tests passing
- **SoC**: 5/5 tests passing

```bash
# Run SoC tests
cd picorv32_soc
make sim
```

## Repository Structure

```
picorv32_soc/
├── rtl/
│   ├── soc_top.sv          # Top-level SoC
│   ├── systolic_array.sv   # 8×8 systolic array
│   ├── pe.sv               # Processing element
│   ├── axilite_slave.sv    # AXI-Lite MMIO
│   ├── spi_slave.sv        # SPI slave interface
│   ├── uart_tx.sv          # UART transmitter
│   ├── isram_256x32.sv     # Instruction SRAM wrapper
│   └── dsram_256x32.sv     # Data SRAM wrapper
├── tb/                     # Testbenches
├── firmware.hex            # Test firmware
└── Makefile
```

## Tools

- **Simulation**: Icarus Verilog / Verilator
- **Synthesis**: Yosys
- **Physical Design**: OpenROAD (ASAP7)
- **Viewer**: KLayout

## Related

- [Systolic Array Caravel Tapeout](https://github.com/RakshithSuresh2001/Systolic-Array) — Sky130 tapeout via ChipFoundry CI2609

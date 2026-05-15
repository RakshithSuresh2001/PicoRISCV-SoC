# PicoRV32 + Systolic Array SoC

A RISC-V SoC integrating a PicoRV32 CPU with an 8×8 weight-stationary systolic array accelerator, targeting ASAP7 7nm via OpenROAD.

## Architecture
┌─────────────────────────────────────────────────────┐
│                    SoC — ASAP7 7nm                  │
│                                                     │
│  ┌─────────────┐         memory bus                 │
│  │  PicoRV32   │─────────────────────────────┐      │
│  │  RV32IMC    │                             │      │
│  │  500 MHz    │                             │      │
│  └─────────────┘                             │      │
│        │                                     │      │
│  ┌─────┴────┐  ┌──────────┐  ┌──────────┐   │      │
│  │ ISRAM    │  │ DSRAM    │  │  UART    │   │      │
│  │ 64 KB    │  │ 32 KB    │  │ 115200   │   │      │
│  └──────────┘  └──────────┘  └──────────┘   │      │
│                                             │      │
│                         ┌───────────────────┘      │
│                         ▼                           │
│                ┌─────────────────┐                  │
│                │  AXI-Lite slave │                  │
│                │  register file  │                  │
│                └────────┬────────┘                  │
│                         ▼                           │
│                ┌─────────────────┐                  │
│                │  8×8 Systolic   │                  │
│                │  Array  64 PEs  │                  │
│                └─────────────────┘                  │
└─────────────────────────────────────────────────────┘

## Memory map

| Base address   | Size  | Block                      |
|----------------|-------|----------------------------|
| 0x0000_0000    | 64 KB | Instruction SRAM           |
| 0x0001_0000    | 32 KB | Data SRAM                  |
| 0x1000_0000    | 4 KB  | Systolic array register file|
| 0x2000_0000    | 4 KB  | UART                       |

## Systolic array register file (base 0x1000_0000)

| Offset | Register       | Description                              |
|--------|----------------|------------------------------------------|
| 0x00   | WEIGHT_ROW     | bits[2:0] = row index (0-7)             |
| 0x04   | WEIGHT_DATA_LO | bits[31:0] = weight_data_flat[31:0]     |
| 0x08   | WEIGHT_DATA_HI | bits[31:0] = weight_data_flat[63:32]    |
| 0x0C   | WEIGHT_LOAD    | write any value = pulse weight_load     |
| 0x10   | ACT_LO         | bits[31:0] = act_in_flat[31:0]          |
| 0x14   | ACT_HI         | bits[31:0] = act_in_flat[63:32]         |
| 0x18   | PSUM_SEL       | bits[2:0] = output column to read       |
| 0x1C   | PSUM_DATA      | bits[31:0] = accumulated result (r/o)   |

## CPU configuration

| Parameter          | Value                        |
|--------------------|------------------------------|
| ISA                | RV32IMC                      |
| Target clock       | 500 MHz (ASAP7)              |
| Instruction SRAM   | 64 KB at 0x0000_0000         |
| Data SRAM          | 32 KB at 0x0001_0000         |
| Stack pointer      | 0x0001_7FFC (top of DSRAM)   |
| Reset vector       | 0x0000_0000                  |
| Hardware multiply  | Enabled                      |
| Compressed ISA     | Enabled                      |
| IRQ lines          | 16 (Phase 3)                 |

## File structure
picorv32-soc/
├── soc_top.sv          # Top-level: CPU, SRAM, address decoder
├── axilite_slave.sv    # AXI-Lite register file for systolic array
├── systolic_array.sv   # 8×8 weight-stationary systolic array RTL
├── pe.sv               # Processing element
├── uart_tx.sv          # 8N1 UART transmitter (500 MHz, 115200 baud)
├── tb_soc_top.sv       # Self-checking testbench
├── test_firmware.c     # Bare-metal C firmware (no libc)
└── link.ld             # Linker script

## Simulation

### Dependencies
- iverilog (Icarus Verilog)
- riscv64-unknown-elf-gcc
- PicoRV32: git clone https://github.com/YosysHQ/picorv32

### Build and run

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

### Expected output
[TB] Reset released
PASS [Test 1] CPU boot PC=0x00000044
INFO firmware completed OK
PASS [Test 3] DSRAM sentinel correct
PASS [Test 4] Stack sp correct
PASS [Test 5] SA all 8 outputs correct
[TB] All tests complete

## Firmware flow

1. Write sentinel 0xDEADBEEF to DSRAM (boot confirmation)
2. Load identity matrix row by row via WEIGHT_ROW + WEIGHT_DATA_LO/HI + WEIGHT_LOAD
3. Feed activation vector [1,2,3,4,5,6,7,8] via ACT_LO/HI
4. Wait for pipeline drain (~20 cycles)
5. Read 8 outputs via PSUM_SEL + PSUM_DATA into DSRAM
6. Write completion flag 0x600DC0DE

## Verification results

| Test   | Description                              | Result |
|--------|------------------------------------------|--------|
| Test 1 | CPU boots, PC advances past reset vector | PASS   |
| Test 3 | Data SRAM write/read (0xDEADBEEF)        | PASS   |
| Test 4 | Stack pointer within DSRAM bounds        | PASS   |
| Test 5 | SA: identity x [1-8] = [1-8] all 8 cols | PASS   |

## Roadmap

- [x] Phase 1 — PicoRV32 + SRAM baseline
- [x] Phase 2 — Systolic array integration and verification
- [ ] Phase 3 — SPI + interrupt-driven operation
- [ ] OpenROAD physical design on ASAP7 7nm
- [ ] PPA report

## Author

Rakshith Suresh — MS EE, USC

LinkedIn: https://linkedin.com/in/rakshith-suresh-890329258

GitHub: https://github.com/RakshithSuresh2001

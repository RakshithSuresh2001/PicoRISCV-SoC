/* =============================================================================
   link.ld — Linker script for PicoRV32 SoC Phase 1 firmware
   Instruction SRAM : 0x0000_0000, 64 KB
   Data SRAM        : 0x0001_0000, 32 KB
   Stack            : top of data SRAM (sp = 0x0001_7FFC at reset via STACKADDR)
   ============================================================================= */

MEMORY {
    ISRAM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    DSRAM (rwx) : ORIGIN = 0x00010000, LENGTH = 32K
}

ENTRY(_start)

SECTIONS {
    /* ── Text: code goes into instruction SRAM ── */
    .text : {
        KEEP(*(.text.start))   /* _start must be at reset vector 0x0000_0000 */
        *(.text*)
        *(.rodata*)
    } > ISRAM

    /* ── Data: initialised globals copied to data SRAM ── */
    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > DSRAM AT > ISRAM      /* LMA in ISRAM, VMA in DSRAM */

    _data_load = LOADADDR(.data);

    /* ── BSS: zero-initialised globals in data SRAM ── */
    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > DSRAM

    /* ── Stack sits at the top of DSRAM (grows downward) ── */
    /* sp is initialised to STACKADDR by PicoRV32 parameter — no explicit section needed */
    _stack_top = ORIGIN(DSRAM) + LENGTH(DSRAM) - 4;
}

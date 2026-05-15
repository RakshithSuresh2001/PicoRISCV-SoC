#define SA_BASE    0x10000000UL
#define DSRAM_BASE 0x00010000UL

#define SA_WEIGHT_ROW     (*(volatile unsigned int *)(SA_BASE + 0x00))
#define SA_WEIGHT_DATA_LO (*(volatile unsigned int *)(SA_BASE + 0x04))
#define SA_WEIGHT_DATA_HI (*(volatile unsigned int *)(SA_BASE + 0x08))
#define SA_WEIGHT_LOAD    (*(volatile unsigned int *)(SA_BASE + 0x0C))
#define SA_ACT_LO         (*(volatile unsigned int *)(SA_BASE + 0x10))
#define SA_ACT_HI         (*(volatile unsigned int *)(SA_BASE + 0x14))
#define SA_PSUM_SEL       (*(volatile unsigned int *)(SA_BASE + 0x18))
#define SA_PSUM_DATA      (*(volatile unsigned int *)(SA_BASE + 0x1C))

void *memcpy(void *dst, const void *src, unsigned long n) {
    char *d = dst; const char *s = src;
    while (n--) *d++ = *s++;
    return dst;
}

// Load one row of weights (8 x INT8 packed into 64 bits)
static void load_weight_row(int row, unsigned char w[8]) {
    SA_WEIGHT_ROW     = row;
    SA_WEIGHT_DATA_LO = ((unsigned int)w[0])       |
                        ((unsigned int)w[1] << 8)  |
                        ((unsigned int)w[2] << 16) |
                        ((unsigned int)w[3] << 24);
    SA_WEIGHT_DATA_HI = ((unsigned int)w[4])       |
                        ((unsigned int)w[5] << 8)  |
                        ((unsigned int)w[6] << 16) |
                        ((unsigned int)w[7] << 24);
    SA_WEIGHT_LOAD = 1; // pulse weight_load
}

// Feed activations (8 x INT8 packed into 64 bits)
static void feed_activations(unsigned char a[8]) {
    SA_ACT_LO = ((unsigned int)a[0])       |
                ((unsigned int)a[1] << 8)  |
                ((unsigned int)a[2] << 16) |
                ((unsigned int)a[3] << 24);
    SA_ACT_HI = ((unsigned int)a[4])       |
                ((unsigned int)a[5] << 8)  |
                ((unsigned int)a[6] << 16) |
                ((unsigned int)a[7] << 24);
}

// Simple delay loop
static void delay(int n) {
    for (volatile int i = 0; i < n; i++);
}

void __attribute__((noreturn, section(".text.start"))) _start(void) {

    volatile unsigned int *dsram =
        (volatile unsigned int *)(DSRAM_BASE + 0x100);

    // Sentinel: firmware started
    dsram[0] = 0xDEADBEEF;

    // Load identity matrix row by row
    // Row r: weight[r][r]=1, all others 0
    unsigned char row_data[8];
    for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++)
            row_data[c] = (r == c) ? 1 : 0;
        load_weight_row(r, row_data);
    }

    // Feed activations [1,2,3,4,5,6,7,8]
    unsigned char act[8] = {1,2,3,4,5,6,7,8};
    feed_activations(act);

    // Wait for pipeline to drain (20 cycles + margin)
    delay(100);

    // Read all 8 outputs into DSRAM
    for (int c = 0; c < 8; c++) {
        SA_PSUM_SEL = c;
        dsram[1 + c] = SA_PSUM_DATA;
    }

    // Done flag
    dsram[9] = 0x600DC0DE;

    while (1) __asm__ volatile ("nop");
}

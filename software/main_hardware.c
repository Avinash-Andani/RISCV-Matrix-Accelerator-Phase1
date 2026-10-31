#include <stdint.h>

#define OUT_START      (*(volatile uint32_t*)0x40000010)
#define HW_MATRIX_DATA (*(volatile uint32_t*)0x40000000)
#define HW_START_CMD   (*(volatile uint32_t*)0x40000004)

// Packs four 8-bit numbers into one 32-bit bus transfer: [31:24]=b1, [23:16]=a1, [15:8]=b0, [7:0]=a0
#define PACK_BUS_32(b1, a1, b0, a0) \
    ( ((uint32_t)(b1) << 24) | ((uint32_t)(a1) << 16) | ((uint32_t)(b0) << 8) | ((uint32_t)(a0)) )

void __attribute__((naked)) _start() {
    asm volatile("li sp, 0x00000FF0"); 
    asm volatile("j main");
}

int main() {
    OUT_START = 1; 

    // Cycle 0 FIFO Write: b_in_1 = 8, a_in_1 = 4, b_in_0 = 6, a_in_0 = 2 (0x08040602)
    HW_MATRIX_DATA = PACK_BUS_32(8, 4, 6, 2); 

    // Cycle 1 FIFO Write: b_in_1 = 7, a_in_1 = 3, b_in_0 = 5, a_in_0 = 1 (0x07030501)
    HW_MATRIX_DATA = PACK_BUS_32(7, 3, 5, 1); 

    // Trigger systolic array computation
    HW_START_CMD = 1; 

    while(1); 
    return 0;
}
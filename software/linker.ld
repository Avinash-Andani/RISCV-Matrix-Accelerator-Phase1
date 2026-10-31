MEMORY {
    RAM (xrw) : ORIGIN = 0x00000000, LENGTH = 4096
}
SECTIONS {
    .text : { 
        *(.text)
        *(.rodata*)
    } > RAM
    .data : { 
        *(.data)
    } > RAM
    .bss : { 
        *(.bss)
    } > RAM
}
# ====================
# Core1 waits for core0 to finish its write miss
# ====================
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
# ====================
# Core1 read miss
# ====================
lw $s0 , 0($zero)          # read from address 0X00000000 - (read miss -> state = S , $s0 = 42)
# ====================
# Core1 waits while Core0 Invalidates the line0 in cache1
# ====================
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
addi $zero, $zero, 0
# ====================
# Line zero in cache1 will turn to I
# After this, Core0 and Core1 will work independently
# Next step is core1 E -> M transition and write back on Line1
# ====================
lw   $s1, 16($zero)         # read from address 0X00000010 - (read miss , $s1 = 0)
addi $t1, $zero, 99         # $t1 = 99
sw   $t1, 16($zero)         # write 99 to address 0X00000010 ( E -> M transition on line1 in cache1)
# ====================
# Reading a newer address mapping to the line1 will cause a write-back to memory at address 0X00000010 (value 99)
# ====================
lw $s2, 80($zero)           # read from address 0X00000050 - (read miss , $s2 = 0) - write back to memory at address 0X00000010 (value 99)
# ====================
# Re-read address 0x00000010 to verify write back success - the value should be 99
# ====================
lw $s3, 16($zero)           # read from address 0X00000010 - (read miss , $s3 = 99)
# ====================
# $s0 (Register 16) = 42, $s1 (Register 17) = 0, $s2 (Register 18) = 0, $s3 (Register 19) = 99 , $t1 (Register 9) = 99
# End of the program
# ===================
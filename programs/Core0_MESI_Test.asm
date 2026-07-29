# ====================
# Core0 write miss
# ====================
addi $t0, $zero, 42         # $t0 = 42
sw   $t0, 0($zero)          # write 42 to address 0X00000000 - (write miss -> state = M)
# ====================
# Delays while core1 executing
# Core1 will read address 0X00000000
# The state for adress line zero in cache0 will turn to S
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
# ====================
# Core0 writes to shared data
# ====================
addi $t0, $t0, 1            # $t0 = 43
sw   $t0, 0($zero)          # overwrite 43 to 0X00000000 (State S -> M, Invalidates Core1)
# ====================
# After this, Core0 and Core1 will work independently
# Now address 0X00000000 is in line0.
# Reading a new address mapping to the line0 will cause a write-back to memory at address 0X00000000 (value 43)
# ====================
lw $t1, 64($zero)           # read from address 0X00000040 - (read miss , $t1 = 0)
# ====================
# Re-read address 0x00000000 to verify write back success - the value should be 43
# ====================
lw $t2, 0($zero)            # read from address 0X00000000 - (read miss , $t2 = 43)
# ====================
# $t0 (Register 8) = 43, $t1 (Register 9) = 0, $t2 (Register 10) = 43
# End of the program
# ====================
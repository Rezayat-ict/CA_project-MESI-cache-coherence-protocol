# =========================================================
# Independent Multi-Core Test: Core 0 Vector Processing
# Input Base Addr: 0x100 (Maps to Line 0) 
# Output Base Addr: 0x200 (Maps to Line 0)
# =========================================================

# --- Load Input Elements from Memory (Brings 0x100 block to Line 0) ---
lw   $t1, 256($zero)        # read from address 0x00000100 - (Read Miss -> Brings block to Line 0, State E)
lw   $t2, 260($zero)        # read from address 0x00000104 - (Read Hit in Line 0)
lw   $t3, 264($zero)        # read from address 0x00000108 - (Read Hit in Line 0)

# --- Perform Computation (Add constant 5 to each element) ---
addi $t1, $t1, 5            # $t1 = $t1 + 5
addi $t2, $t2, 5            # $t2 = $t2 + 5
addi $t3, $t3, 5            # $t3 = $t3 + 5

# --- Store Results to Output Memory (Evicts 0x100 block, brings 0x200 block) ---
sw   $t1, 512($zero)        # write to 0x00000200 - (Write Miss / Conflict). Evicts 0x100 block. Brings 0x200 to Line 0 -> State M.
sw   $t2, 516($zero)        # write to 0x00000204 - (Write Hit in Line 0 -> State M)
sw   $t3, 520($zero)        # write to 0x00000208 - (Write Hit in Line 0 -> State M)

# --- Force Write-Back by reading the original array again (Evicts 0x200 block) ---
lw   $t4, 256($zero)        # read from 0x00000100 - (Read Miss / Conflict). Causes WRITE-BACK of 0x200 block to memory! Brings 0x100 to Line 0.
lw   $t5, 260($zero)        # read from 0x00000104 - (Read Hit in Line 0)
lw   $t6, 264($zero)        # read from 0x00000108 - (Read Hit in Line 0)

# --- Verify Write-Back by reading output array into new registers ---
lw   $s0, 512($zero)        # read from 0x00000200 - (Read Miss / Conflict). Evicts 0x100 block. Brings 0x200 back to Line 0.
lw   $s1, 516($zero)        # read from 0x00000204 - (Read Hit in Line 0)
lw   $s2, 520($zero)        # read from 0x00000208 - (Read Hit in Line 0)

# ====================
# Final Register States:
# Assuming initial memory values were zero, the final register values will be:
# ====================
# $t1 (Register 9)  = 5
# $t2 (Register 10) = 5
# $t3 (Register 11) = 5
#
# $t4 (Register 12) = 0
# $t5 (Register 13) = 0
# $t6 (Register 14) = 0
#
# $s0 (Register 16) = 5  (Verifies Write-Back of 0x200 was successful)
# $s1 (Register 17) = 5  (Verifies Write-Back of 0x204 was successful)
# $s2 (Register 18) = 5  (Verifies Write-Back of 0x208 was successful)
#
# End of the program
# ====================
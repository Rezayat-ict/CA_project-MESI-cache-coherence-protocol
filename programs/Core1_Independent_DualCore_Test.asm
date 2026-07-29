# =========================================================
# Independent Multi-Core Test: Core 1 Vector Loop Processing
# Input Base Addr: 0x300 (Dec: 768) | Output Base Addr: 0x400 (Dec: 1024)
# =========================================================

# --- Step 1: Initialize input array with random/non-zero values using sw ---
addi $t0, $zero, 10         # Value 1 (Even)
addi $t1, $zero, 15         # Value 2 (Odd)
addi $t2, $zero, 22         # Value 3 (Even)
addi $t3, $zero, 33         # Value 4 (Odd)

sw   $t0, 768($zero)        # Mem[0x300] = 10
sw   $t1, 772($zero)        # Mem[0x304] = 15
sw   $t2, 776($zero)        # Mem[0x308] = 22
sw   $t3, 780($zero)        # Mem[0x30C] = 33

# --- Step 2: Initialization for Vector Loop ---
addi $s4, $zero, 4          # Loop Counter = 4 (Array size)
addi $t8, $zero, 768        # Input base address pointer (0x300)
addi $t9, $zero, 1024       # Output base address pointer (0x400)

# Create constant bitmask '1' using ori instruction
ori  $t7, $zero, 1          # $t7 = 1 (Bitmask for modulo 2 / even-odd check)

# =========================================================
# Vector Loop (Processes 4 elements)
# =========================================================
vector_loop:
# 1. Load element from input array
lw   $s1, 0($t8)            # Read current input element

# 2. Compute remainder when divided by 2 (Element AND 1)
and  $s2, $s1, $t7          # $s2 = Element & 1 (Result: 0 for 10 and 22, 1 for 15 and 33)

# 3. Store result to output array
sw   $s2, 0($t9)            # Mem[Output_Ptr] = $s2

# 4. Advance pointers and decrement counter
addi $t8, $t8, 4            # Move input pointer to the next 4-byte word
addi $t9, $t9, 4            # Move output pointer to the next 4-byte word
addi $s4, $s4, -1           # Decrement loop counter by 1

# 5. Loop branch condition (Branch if counter != 0)
bne  $s4, $zero, vector_loop  # If $s4 != 0, jump back to 'vector_loop'

# =========================================================
# Step 3: Verify outputs by loading them back into $t0 to $t3
# =========================================================
lw   $t0, 1024($zero)       # Load output element 0 (Expected: 0 from 10 & 1)
lw   $t1, 1028($zero)       # Load output element 1 (Expected: 1 from 15 & 1)
lw   $t2, 1032($zero)       # Load output element 2 (Expected: 0 from 22 & 1)
lw   $t3, 1036($zero)       # Load output element 3 (Expected: 1 from 33 & 1)

# =========================================================
# Final Register States:
# $s4 (Register 20) = 0
# $t7 (Register 15) = 1
# $s1 (Register 17) = Last loaded input element (33)
# $s2 (Register 18) = Remainder of last element (33 & 1 = 1)
# $t0 (Register 8)  = 0 (Output[0] verified)
# $t1 (Register 9)  = 1 (Output[1] verified)
# $t2 (Register 10) = 0 (Output[2] verified)
# $t3 (Register 11) = 1 (Output[3] verified)
#
# End of Core 1 Program
# =========================================================
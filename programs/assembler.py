import sys
import os

def assemble_file(input_filepath):
    if not os.path.exists(input_filepath):
        print(f"Error: File '{input_filepath}' not found!")
        return

    with open(input_filepath, 'r') as f:
        lines = f.readlines()

    labels = {}
    instructions = []
    
    for line in lines:
        original_line = line.strip()
        line = original_line.split('#')[0].strip()
        if not line:
            continue
            
        if ':' in line:
            parts = line.split(':')
            label_name = parts[0].strip()
            labels[label_name] = len(instructions)
            rest = parts[1].strip()
            if rest:
                instructions.append((rest, original_line))
        else:
            instructions.append((line, original_line))

    def reg_to_bin(reg_str):
        reg_map = {
            '$zero': 0, '$0': 0,
            '$t0': 8,  '$8': 8,
            '$t1': 9,  '$9': 9,
            '$t2': 10, '$10': 10,
            '$t3': 11, '$11': 11,
            '$t4': 12, '$12': 12,
            '$t5': 13, '$13': 13,
            '$t6': 14, '$14': 14,
            '$t7': 15, '$15': 15,
            '$t8': 24, '$24': 24,
            '$t9': 25, '$25': 25,
            '$s0': 16, '$16': 16,
            '$s1': 17, '$17': 17,
            '$s2': 18, '$18': 18,
            '$s3': 19, '$19': 19,
            '$s4': 20, '$20': 20,
            '$k0': 26, '$26': 26,
            '$k1': 27, '$27': 27,
        }
        val = reg_map.get(reg_str, 0)
        return format(val, '05b')

    binary_instructions = []

    for pc, (line, orig) in enumerate(instructions):
        parts = line.replace(',', '').split()
        mnemonic = parts[0]

        def imm_to_bin(imm_str, current_pc):
            if imm_str in labels:
                # محاسبه Branch Offset بر اساس PC معادل استاندارد MIPS (PC = current_pc + 1)
                offset = labels[imm_str] - (current_pc + 1)
                val = offset
            else:
                val = int(imm_str, 0)
            
            if val < 0:
                val = (1 << 16) + val
            return format(val, '016b')

        if mnemonic in ['add', 'sub', 'and', 'or', 'slt']:
            opcode = "000000"
            rd = reg_to_bin(parts[1])
            rs = reg_to_bin(parts[2])
            rt = reg_to_bin(parts[3])
            shamt = "00000"
            
            func_map = {
                'add': '100000', 
                'sub': '100010', 
                'and': '100100', 
                'or':  '100101',
                'slt': '101010'
            }
            bin_inst = opcode + rs + rt + rd + shamt + func_map[mnemonic]

        elif mnemonic in ['addi', 'ori', 'lw', 'sw', 'bne']:
            if mnemonic in ['lw', 'sw']:
                rt = reg_to_bin(parts[1])
                offset_str, base_str = parts[2].replace(')', '').split('(')
                rs = reg_to_bin(base_str)
                imm = imm_to_bin(offset_str, pc)
            elif mnemonic == 'bne':
                rs = reg_to_bin(parts[1])
                rt = reg_to_bin(parts[2])
                imm = imm_to_bin(parts[3], pc)
            else: # addi, ori
                rt = reg_to_bin(parts[1])
                rs = reg_to_bin(parts[2])
                imm = imm_to_bin(parts[3], pc)

            op_map = {
                'addi': '001000',
                'ori':  '001101',
                'lw':   '100011',
                'sw':   '101011',
                'bne':  '000101'
            }
            bin_inst = op_map[mnemonic] + rs + rt + imm
        else:
            continue

        binary_instructions.append(bin_inst)

    base_name = os.path.splitext(input_filepath)[0]
    output_filepath = f"{base_name}_decoded.txt"

    with open(output_filepath, 'w') as f:
        f.write(f"{len(binary_instructions)}\n")
        for inst in binary_instructions:
            f.write(f"{inst}\n")

    print(f"Success! Converted {len(binary_instructions)} instructions with label resolution.")
    print(f"Output saved to: {output_filepath}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python assembler.py <path_to_assembly_file>")
    else:
        assemble_file(sys.argv[1])
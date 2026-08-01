# Dual-Core MIPS Processor with L1 Cache and MESI Protocol

## Overview

This project implements a dual-core MIPS processor system using Verilog.

Each core contains a pipelined MIPS processor connected to a private L1 cache. 
The system supports cache coherence between the two cores using the MESI cache coherence protocol.

The main components of the project include:

- Dual-core MIPS processor
- Five-stage pipeline architecture
- Private L1 caches for each core
- Shared bus communication
- MESI cache coherence protocol
- Independent execution and coherence test scenarios


## Assembly Programs

The assembly programs used for testing the processor are converted into binary instruction files using the `assembler.py` script located in the `programs` directory.

The generated `.txt` files are used as instruction memory initialization files for each core.

Each generated file has the following format:

- The first line contains the total number of instructions.
- The following lines contain the binary representation of instructions in execution order.

These instruction files are loaded into the instruction memory of each core during simulation.


## Requirements

To simulate the project, a Verilog simulator is required.

The project has been tested using:

- Icarus Verilog

Other Verilog simulators may also be used.


## Running Simulation with Icarus Verilog

The simulations can be run using different Verilog simulators.  
For example, using **Icarus Verilog**, execute the following commands from the `tb` directory.

### Independent Execution Test

Compile:

```bash
iverilog -I ../rtl -o sim_indep dual_core_Independent_tb.v ../rtl/*.v
```

Run:

```bash
vvp sim_indep
```

### MESI Protocol Test

Compile:

```bash
iverilog -I ../rtl -o sim_mesi dual_core_MESI_tb.v ../rtl/*.v
```

Run:

```bash
vvp sim_mesi
```

The commands above are examples using Icarus Verilog. Other Verilog simulators can also be used with the corresponding compilation and simulation commands.


## Testbenches

Two main testbenches are provided to verify the functionality of the dual-core system.

### 1. Independent Execution Test

`dual_core_Independent_tb.v`

This testbench verifies that both cores can execute independent programs correctly.

The test includes:
- Running separate programs on each core.
- Checking the final register values of both cores.
- Verifying that the expected results are produced after program execution.

At the end of the simulation, the testbench automatically compares the actual register values with the expected values and reports the test result.


### 2. MESI Protocol Test

`dual_core_MESI_tb.v`

This testbench verifies the cache coherence behavior between the two cores using the MESI protocol.

The test includes:
- Executing programs that require shared memory access.
- Testing cache coherence operations between L1 caches.
- Checking the final register values after all memory transactions.

The testbench automatically validates the expected register values and reports whether the MESI protocol execution is correct.


## Simulation Result

Each testbench performs automatic verification at the end of the simulation.

The final register values are compared against the expected values defined in the testbench.

A successful simulation should finish with a `PASS` message, indicating that the processor pipeline, cache subsystem, and (for the MESI test) cache coherence mechanism are operating correctly.


## Team Members

- Khorshid Bahoush
- Fateme Keshavarz
- MohammadReza Rezayat
- MohammadHossein Majdian

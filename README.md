# Dual-Core MIPS Processor with L1 Cache, Victim Cache, and MESI Protocol

## Overview

This project implements a dual-core MIPS processor system using Verilog.

Each core contains a pipelined MIPS processor connected to a private L1 cache. The system supports cache coherence between the two cores using the MESI cache coherence protocol.

In addition, each L1 cache is equipped with a **Victim Cache** to reduce conflict misses. The Victim Cache is placed between the L1 cache and the shared bus interface.

The main components of the project include:

- Dual-core MIPS processor
- Five-stage pipeline architecture
- Private L1 caches for each core
- 4-entry Fully Associative Victim Cache for each L1 cache
- Shared bus communication
- MESI cache coherence protocol
- Independent execution and coherence test scenarios

---

## Victim Cache

Each processor core includes a dedicated Victim Cache located between the L1 cache and the bus arbiter.

The Victim Cache has the following characteristics:

- Capacity of **4 cache lines**
- **Fully Associative** organization
- Positioned between the **L1 Cache** and the **Bus Arbiter**

Whenever a cache line is evicted from the L1 cache, it is first placed into the Victim Cache. On an L1 cache miss, the Victim Cache is checked before issuing a request to the shared bus, reducing conflict misses and unnecessary memory transactions.

---

## Assembly Programs

The assembly programs used for testing the processor are converted into binary instruction files using the `assembler.py` script located in the `programs` directory.

The generated `.txt` files are used as instruction memory initialization files for each core.

Each generated file has the following format:

- The first line contains the total number of instructions.
- The following lines contain the binary representation of instructions in execution order.

These instruction files are loaded into the instruction memory of each core during simulation.

---

## Requirements

To simulate the project, a Verilog simulator is required.

The project has been tested using:

- Icarus Verilog

Other Verilog simulators may also be used.

---

## Running Simulations

The simulations can be run using different Verilog simulators.

For example, using **Icarus Verilog**, execute the following scripts **from the `tb` directory**.

### Windows

```text
run_all_tests.bat
```

or run each test individually:

```text
run_independent.bat
run_mesi.bat
run_victim_cache.bat
```

### Linux / macOS

```bash
chmod +x run_all_tests.sh
./run_all_tests.sh
```

or run each test individually:

```bash
chmod +x run_*.sh

./run_independent.sh
./run_mesi.sh
./run_victim_cache.sh
```

The commands above are examples using Icarus Verilog. Other Verilog simulators can also be used with the corresponding compilation and simulation commands.

---

## Testbenches

Three testbenches are provided to verify different parts of the design.

### 1. Independent Execution Test

`dual_core_Independent_tb.v`

This testbench verifies that both processor cores can execute independent programs correctly.

The test includes:

- Running different programs on each core.
- Verifying correct pipeline execution.
- Checking the final register values of both cores.

At the end of the simulation, the expected register values are compared automatically and the testbench reports **PASS** or **FAIL**.

---

### 2. MESI Protocol Test

`dual_core_MESI_tb.v`

This testbench verifies cache coherence between the two processor cores.

The test includes:

- Shared memory accesses.
- Cache coherence transactions.
- MESI state transitions.
- Final register value verification.

The expected register values are checked automatically and the testbench reports **PASS** or **FAIL**.

---

### 3. Victim Cache Test

`tb_victim_cache.v`

This testbench verifies the functionality of the Victim Cache.

The test includes:

- Cache line eviction from the L1 cache.
- Victim Cache insertion.
- Victim Cache hit handling.
- Correct data retrieval from the Victim Cache.
- Automatic verification of the expected behavior.

The testbench reports **PASS** or **FAIL** at the end of the simulation.

---

## Simulation Result

Each testbench performs automatic verification at the end of the simulation.

The final register values (or cache behavior for the Victim Cache test) are compared against the expected results defined in the testbench.

A successful simulation finishes with a **PASS** message, indicating that the tested subsystem is functioning correctly.

---

## Team Members

- Khorshid Bahoush
- Fateme Keshavarz
- MohammadReza Rezayat
- MohammadHossein Majdian
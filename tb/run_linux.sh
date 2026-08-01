#!/bin/bash

set -e

echo "==========================================="
echo "Running Independent Test"
echo "==========================================="

iverilog -I ../rtl -o Independent_Simulation \
dual_core_Independent_tb.v \
../rtl/*.v

vvp Independent_Simulation


echo
echo "==========================================="
echo "Running MESI Test"
echo "==========================================="

iverilog -I ../rtl -o MESI_Simulation \
dual_core_MESI_tb.v \
../rtl/*.v

vvp MESI_Simulation


echo
echo "==========================================="
echo "Running Victim Cache Test"
echo "==========================================="

iverilog -I ../rtl -o Victim_Simulation \
tb_victim_cache.v \
../rtl/victim_cache.v \
../rtl/l1_cache.v \
../rtl/cache2_bus_adapter.v

vvp Victim_Simulation


echo
echo "==========================================="
echo "All simulations completed successfully."
echo "==========================================="
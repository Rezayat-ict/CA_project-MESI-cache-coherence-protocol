@echo off

echo ===========================================
echo Running Independent Test
echo ===========================================

iverilog -I ../rtl -o Independent_Simulation dual_core_Independent_tb.v ../rtl/*.v
if errorlevel 1 goto error

vvp Independent_Simulation
if errorlevel 1 goto error


echo.
echo ===========================================
echo Running MESI Test
echo ===========================================

iverilog -I ../rtl -o MESI_Simulation dual_core_MESI_tb.v ../rtl/*.v
if errorlevel 1 goto error

vvp MESI_Simulation
if errorlevel 1 goto error


echo.
echo ===========================================
echo Running Victim Cache Test
echo ===========================================

iverilog -I ../rtl -o Victim_Simulation ^
tb_victim_cache.v ^
../rtl/victim_cache.v ^
../rtl/l1_cache.v ^
../rtl/cache2_bus_adapter.v
if errorlevel 1 goto error

vvp Victim_Simulation
if errorlevel 1 goto error


echo.
echo ===========================================
echo All simulations completed successfully.
echo ===========================================
pause
exit /b

:error
echo.
echo ===========================================
echo Simulation aborted due to an error.
echo ===========================================
pause
exit /b 1
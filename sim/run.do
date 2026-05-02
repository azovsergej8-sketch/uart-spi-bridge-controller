vlib work
vlog -sv ../src/uart_rx.sv
vlog -sv ../src/uart_tx.sv
vlog -sv ../src/spi_master.sv
vlog -sv ../src/top_module.sv

# Компилируем Тестбенч
vlog -sv ../tb/tb_top.sv

# Запускаем симуляцию
vsim -voptargs="+acc" work.tb_top

# Добавляем все сигналы на график Wave
add wave -position insertpoint sim:/tb_top/*
add wave -position insertpoint sim:/tb_top/dut/*

# Запускаем выполнение до упора
run -all

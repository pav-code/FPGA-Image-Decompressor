onbreak {resume}
transcript on

set PrefMain(saveLines) 50000
.main clear

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

# load designs
vlog -sv -work rtl_work convert_hex_to_seven_segment.v
vlog -sv -work rtl_work VGA_Controller.v
vlog -sv -work rtl_work PB_Controller.v
vlog -sv -work rtl_work +define+SIMULATION SRAM_Controller.v
vlog -sv -work rtl_work tb_SRAM_Emulator.v
vlog -sv -work rtl_work +define+SIMULATION UART_Receive_Controller.v
vlog -sv -work rtl_work VGA_SRAM_interface.v
vlog -sv -work rtl_work UART_SRAM_interface.v
vlog -sv -work rtl_work Clock_100_PLL.v
vlog -sv -work rtl_work mil1_FSM.v
vlog -sv -work rtl_work tb_mil1_FSM.v

# specify library for simulation
vsim -t 100ps -L altera_mf_ver -lib rtl_work tb_mil1_FSM

# Clear previous simulation
restart -f

# run complete simulation
run -all

destroy .structure
destroy .signals
destroy .source

simstats

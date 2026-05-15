export PLATFORM           = asap7
export DESIGN_NAME        = soc_top
export VERILOG_FILES      = $(DESIGN_DIR)/picorv32.v \
                            $(DESIGN_DIR)/pe.sv \
                            $(DESIGN_DIR)/systolic_array.sv \
                            $(DESIGN_DIR)/uart_tx.sv \
                            $(DESIGN_DIR)/axilite_slave.sv \
                            $(DESIGN_DIR)/soc_top.sv
export SDC_FILE           = $(DESIGN_DIR)/constraint.sdc
export CORE_UTILIZATION   = 20
export CORE_ASPECT_RATIO  = 1
export CORE_MARGIN        = 2
export PLACE_DENSITY      = 0.50
export CLOCK_PERIOD       = 3000
export LEC_ENABLE         = 0
export LEC_CHECK          = 0
export ABC_AREA           = 1
export SYNTH_MEMORY_MAX_BITS = 32768
export PDN_TCL = $(DESIGN_DIR)/pdn.tcl

pwd
cd [get_property DIRECTORY [current_project]]

file copy -force ../../../soft/perf/obj/bitcount/axi_ram.mif ./mycpu.sim/sim_1/behav/xsim/axi_ram.mif
restart
run all


file copy -force ../../../soft/perf/obj/bubble_sort/axi_ram.mif ./mycpu.sim/sim_1/behav/xsim/axi_ram.mif
restart
run all


file copy -force ../../../soft/perf/obj/coremark/axi_ram.mif ./mycpu.sim/sim_1/behav/xsim/axi_ram.mif
restart
run all


file copy -force ../../../soft/perf/obj/crc32/axi_ram.mif ./mycpu.sim/sim_1/behav/xsim/axi_ram.mif
restart
run all


file copy -force ../../../soft/perf/obj/dhrystone/axi_ram.mif ./mycpu.sim/sim_1/behav/xsim/axi_ram.mif
restart
run all


file copy -force ../../../soft/perf/obj/quick_sort/axi_ram.mif ./mycpu.sim/sim_1/behav/xsim/axi_ram.mif
restart
run all


file copy -force ../../../soft/perf/obj/select_sort/axi_ram.mif ./mycpu.sim/sim_1/behav/xsim/axi_ram.mif
restart
run all


file copy -force ../../../soft/perf/obj/sha/axi_ram.mif ./mycpu.sim/sim_1/behav/xsim/axi_ram.mif
restart
run all


file copy -force ../../../soft/perf/obj/stream_copy/axi_ram.mif ./mycpu.sim/sim_1/behav/xsim/axi_ram.mif
restart
run all


file copy -force ../../../soft/perf/obj/stringsearch/axi_ram.mif ./mycpu.sim/sim_1/behav/xsim/axi_ram.mif
restart
run all


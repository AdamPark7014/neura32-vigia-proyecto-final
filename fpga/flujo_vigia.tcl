set campos 0
set cada   2
if {[llength $argv] > 0} { set campos [lindex $argv 0] }
if {[llength $argv] > 1} { set cada   [lindex $argv 1] }

set bits_campo [expr {16 + 160 * 60 * 4 + 80 * 30 * 8}]

set hw  [lindex [get_hardware_names] 0]
set dev [lindex [get_device_names -hardware_name $hw] 0]
open_device -hardware_name $hw -device_name $dev
device_lock -timeout 10000
device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value

set n 0
while {$campos == 0 || $n < $campos} {
    set t0 [clock milliseconds]
    set hex [device_virtual_dr_shift -instance_index 0 -length $bits_campo -value_in_hex]
    puts "CAMPO [expr {[clock milliseconds] - $t0}]"
    puts $hex
    incr n
    if {$n % $cada == 0} {
        device_virtual_ir_shift -instance_index 0 -ir_value 2 -no_captured_ir_value
        puts "MASCARA"
        puts [device_virtual_dr_shift -instance_index 0 -length 4800 -value_in_hex]
        device_virtual_ir_shift -instance_index 0 -ir_value 3 -no_captured_ir_value
        puts "DATOS"
        puts [device_virtual_dr_shift -instance_index 0 -length 384 -value_in_hex]
        device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value
    }
    flush stdout
}
device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value
device_unlock
close_device

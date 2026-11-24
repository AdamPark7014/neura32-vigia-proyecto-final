set cuadros 0
set modo    2
set periodo 0
if {[llength $argv] > 0} { set cuadros [lindex $argv 0] }
if {[llength $argv] > 1} { set modo    [lindex $argv 1] }
if {[llength $argv] > 2} { set periodo [lindex $argv 2] }

if {$modo == 1} { set ancho 320; set alto 240 } else { set ancho 160; set alto 120 }
set bits [expr {$ancho * $alto * 8}]

set hw  [lindex [get_hardware_names] 0]
set dev [lindex [get_device_names -hardware_name $hw] 0]
open_device -hardware_name $hw -device_name $dev
device_lock -timeout 10000
device_virtual_ir_shift -instance_index 0 -ir_value $modo -no_captured_ir_value

set n 0
while {$cuadros == 0 || $n < $cuadros} {
    set t0 [clock milliseconds]
    set hex [device_virtual_dr_shift -instance_index 0 -length $bits -value_in_hex]
    puts "CUADRO $n [expr {[clock milliseconds] - $t0}] $ancho $alto"
    puts $hex
    flush stdout
    incr n
    set falta [expr {$periodo - ([clock milliseconds] - $t0)}]
    if {$falta > 0} { after $falta }
}
device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value
device_unlock
close_device

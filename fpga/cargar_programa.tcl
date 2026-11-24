set archivo [lindex $argv 0]
if {$archivo == ""} { puts "falta el archivo del programa"; exit 1 }

set hw  [lindex [get_hardware_names] 0]
set dev [lindex [get_device_names -hardware_name $hw] 0]
open_device -hardware_name $hw -device_name $dev
device_lock -timeout 10000

proc estado {} {
    device_virtual_ir_shift -instance_index 1 -ir_value 3 -no_captured_ir_value
    set hex [device_virtual_dr_shift -instance_index 1 -length 34 -value_in_hex]
    set v [expr "0x$hex"]
    puts [format "LED = %010b   displays (HEX5..HEX0) = %06X" [expr {($v >> 24) & 0x3FF}] [expr {$v & 0xFFFFFF}]]
}

if {$archivo != "estado"} {
    # leer el archivo
    set palabras {}
    set f [open $archivo r]
    while {[gets $f linea] >= 0} {
        regsub {//.*$} $linea "" linea
        set linea [string trim $linea]
        if {$linea == ""} continue
        if {[string index $linea 0] == "@"} continue
        lappend palabras [expr "0x$linea"]
    }
    close $f
    set n [llength $palabras]
    if {$n > 4096} { puts "el programa no cabe: $n palabras (maximo 4096)"; exit 1 }

    # detener el procesador
    device_virtual_ir_shift -instance_index 1 -ir_value 2 -no_captured_ir_value
    device_virtual_dr_shift -instance_index 1 -length 1 -dr_value 1 -no_captured_dr_value

    # escribir
    set t0 [clock milliseconds]
    device_virtual_ir_shift -instance_index 1 -ir_value 1 -no_captured_ir_value
    set dir 0
    foreach p $palabras {
        device_virtual_dr_shift -instance_index 1 -length 44 -dr_value [format %08X%03X $p $dir] -value_in_hex -no_captured_dr_value
        incr dir
    }
    for {set k 0} {$k < 16 && $dir < 4096} {incr k} {
        device_virtual_dr_shift -instance_index 1 -length 44 -dr_value [format %08X%03X 0x00000013 $dir] -value_in_hex -no_captured_dr_value
        incr dir
    }

    # soltar el procesador
    device_virtual_ir_shift -instance_index 1 -ir_value 2 -no_captured_ir_value
    device_virtual_dr_shift -instance_index 1 -length 1 -dr_value 0 -no_captured_dr_value
    puts "programa cargado: $n palabras de $archivo en [expr {[clock milliseconds] - $t0}] ms"
    after 300
}
estado
device_virtual_ir_shift -instance_index 1 -ir_value 0 -no_captured_ir_value
device_unlock
close_device

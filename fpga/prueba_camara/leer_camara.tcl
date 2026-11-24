set hw  [lindex [get_hardware_names] 0]
set dev [lindex [get_device_names -hardware_name $hw] 0]
start_insystem_source_probe -device_name $dev -hardware_name $hw

proc campo {v alto bajo} { return [expr {($v >> $bajo) & ((1 << ($alto - $bajo + 1)) - 1)}] }

proc leer {{callado 0}} {
    set hex [read_probe_data -instance_index 0 -value_in_hex]
    set v [expr "0x$hex"]
    if {!$callado} {
        puts [format "  PID=%02X VER=%02X hecho=%d cuadros=%d" [campo $v 95 88] [campo $v 87 80] [campo $v 79 79] [campo $v 78 71]]
        puts [format "  bytes/linea=%d  lineas/cuadro=%d  PCLK=%d Hz  lineas malas=%d" [campo $v 70 60] [campo $v 59 50] [campo $v 49 27] [campo $v 10 1]]
        puts [format "  D que llegan a 1 (OR)=%02X  D que llegan a 0 (AND)=%02X" [campo $v 26 19] [campo $v 18 11]]
    }
    return $v
}

set fase 2
set i [lsearch $argv fase]
if {$i >= 0} { set fase [lindex $argv [expr {$i + 1}]] }

if {[lsearch $argv barrer] >= 0} {
    for {set f 0} {$f < 4} {incr f} {
        write_source_data -instance_index 0 -value [format %X [expr {$f << 1}]] -value_in_hex
        after 1500
        set peor 0; set suma 0
        for {set k 0} {$k < 8} {incr k} {
            set m [campo [leer 1] 10 1]
            set suma [expr {$suma + $m}]
            if {$m > $peor} { set peor $m }
            after 200
        }
        set v [leer 1]
        puts [format "FASE %d (%3d grados): lineas malas por cuadro: promedio %.1f, peor %d   PCLK=%d Hz" $f [expr {$f * 90}] [expr {$suma / 8.0}] $peor [campo $v 49 27]]
    }
    write_source_data -instance_index 0 -value [format %X [expr {$fase << 1}]] -value_in_hex
    puts "queda en la fase $fase"
} else {
    if {$i >= 0 || [lsearch $argv reiniciar] >= 0} {
        if {[lsearch $argv reiniciar] >= 0} {
            write_source_data -instance_index 0 -value [format %X [expr {($fase << 1) | 1}]] -value_in_hex
            after 100
        }
        write_source_data -instance_index 0 -value [format %X [expr {$fase << 1}]] -value_in_hex
        puts "fase $fase puesta"
        after 2500
    }
    for {set k 0} {$k < 2} {incr k} {
        puts "lectura $k"
        leer
        after 1200
    }
}
end_insystem_source_probe

# Escribe o lee registros de la camara OV7670 en vivo (sin recompilar).
# Uso (desde fpga/prueba_camara), todo en hexadecimal:
#   quartus_stp -t camara_reg.tcl w 17 13 18 01      escribe 0x17 = 0x13 y 0x18 = 0x01
#   quartus_stp -t camara_reg.tcl r 00 10 07         lee esos registros
#   quartus_stp -t camara_reg.tcl a ajustes.txt      aplica un archivo: "RR VV" por renglon (// comenta)
# La fuente de la sonda son 21 bits:
#   [0] reinicio  [2:1] fase de XCLK  [10:3] valor  [18:11] registro  [19] escribir  [20] leer
set FASE 2

set hw  [lindex [get_hardware_names] 0]
set dev [lindex [get_device_names -hardware_name $hw] 0]
start_insystem_source_probe -device_name $dev -hardware_name $hw

proc fuente {rd wr reg val} {
    global FASE
    set v [expr {($rd << 20) | ($wr << 19) | ($reg << 11) | ($val << 3) | ($FASE << 1)}]
    write_source_data -instance_index 0 -value [format %06X $v] -value_in_hex
}

proc esperar_libre {} {
    for {set k 0} {$k < 50} {incr k} {
        set v [expr "0x[read_probe_data -instance_index 0 -value_in_hex]"]
        if {($v >> 104) & 1} { return $v }
        after 2
    }
    puts "AVISO: el maestro SCCB no quedo libre"
    return $v
}

proc escribir {reg val} {
    fuente 0 0 $reg $val
    fuente 0 1 $reg $val
    after 3
    esperar_libre
    fuente 0 0 $reg $val
}

proc leer {reg} {
    fuente 0 0 $reg 0
    fuente 1 0 $reg 0
    after 4
    set v [esperar_libre]
    fuente 0 0 $reg 0
    return [expr {($v >> 96) & 0xFF}]
}

set orden [lindex $argv 0]
if {$orden == "w"} {
    foreach {r x} [lrange $argv 1 end] {
        escribir [expr "0x$r"] [expr "0x$x"]
        puts [format "escrito %02X = %02X" [expr "0x$r"] [expr "0x$x"]]
    }
} elseif {$orden == "r"} {
    foreach r [lrange $argv 1 end] {
        puts [format "REG %02X = %02X" [expr "0x$r"] [leer [expr "0x$r"]]]
    }
} elseif {$orden == "a"} {
    set f [open [lindex $argv 1] r]
    set n 0
    while {[gets $f linea] >= 0} {
        regsub {//.*$} $linea "" linea
        set linea [string trim $linea]
        if {$linea == ""} continue
        escribir [expr "0x[lindex $linea 0]"] [expr "0x[lindex $linea 1]"]
        incr n
    }
    close $f
    puts "aplicados $n registros de [lindex $argv 1]"
}
end_insystem_source_probe

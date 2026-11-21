# Agrega NEURA-32 Vigia como segundo diseno del workspace Lab_Arquitecturas (la
# Student Edition permite 2 disenos por workspace), compila todo y corre la
# ROM de instrucciones de la clase en el procesador.
#
# Uso en la consola de Active-HDL (con el workspace Lab_Arquitecturas abierto):
#   do "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116/Entregas/Proyecto-Final-NEURA32/activehdl/agregar_diseno.do"
#
# Si el diseno ya existe: do archivos.do (si faltan archivos) y do compilar.do.
# Despues: simular_clase.do, simular_control.do, simular_memoria.do, simular_isa.do,
#          simular_red.do o simular_vigia.do

set LAB "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116"
set PROY "$LAB/Entregas/Proyecto-Final-NEURA32"

design create -a Proyecto_NEURA32 "$LAB/activehdl/Lab_Arquitecturas"

do "$PROY/activehdl/archivos.do"
do "$PROY/activehdl/compilar.do"
do "$PROY/activehdl/simular_clase.do"

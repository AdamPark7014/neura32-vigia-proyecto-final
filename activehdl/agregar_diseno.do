set LAB "C:/Users/adpoz/OneDrive/Documentos/Universidad/2026-Semestre-5/09-Lab-Arquitecturas-LA116"
set PROY "$LAB/Entregas/Proyecto-Final-NEURA32"

design create -a Proyecto_NEURA32 "$LAB/activehdl/Lab_Arquitecturas"

do "$PROY/activehdl/archivos.do"
do "$PROY/activehdl/compilar.do"
do "$PROY/activehdl/simular_ab_c.do"

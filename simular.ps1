<#
.SYNOPSIS
  Simula NEURA-32 Vigia con Icarus Verilog: el programa de la clase, el procesador y el sistema completo.

.DESCRIPTION
  1. Escribe los programas en archivos de texto en hexadecimal (fpga\programa_*.txt) con el
     ensamblador en Verilog (tb\generar_rom.v). Son los archivos que lee la memoria de programa.
  2. Corre los bancos de prueba:
       tb_programa_ab_c   el programa (a + b) * c de la clase, sin cambiarlo, en el procesador final
       tb_uc_simple       recorrido de la maquina de estados por tipo de instruccion
       tb_prueba_isa      las 49 instrucciones (tablas OP_R1, OP_R2, OP_R3, memoria, saltos, division)
       tb_red_neuronal    clasificador 3x3 contra un modelo de referencia
       tb_cargador        otro programa cargado por JTAG con el procesador corriendo
       tb_vision          camara a color, mascara, monitor y vista en la PC
       tb_vigia           sistema completo con el modelo de la camara OV7670: camara movida, perro
                          (sin alarma) y persona (cruce prohibido e intrusion). Tarda cerca de una hora.
  La salida de cada banco queda en tb\<banco>.txt; las imagenes de tb_vigia se convierten a PNG en docs\img.
  Sale con codigo 1 si algun banco reporta errores.

.PARAMETER Pruebas
  Bancos a correr (por omision todos).
.PARAMETER Rapido
  Todos menos tb_vigia.

.EXAMPLE
  pwsh -File simular.ps1 -Rapido
  pwsh -File simular.ps1 -Pruebas tb_prueba_isa
#>
param(
    [string[]]$Pruebas = @('tb_programa_ab_c', 'tb_uc_simple', 'tb_prueba_isa', 'tb_red_neuronal',
                           'tb_cargador', 'tb_vision', 'tb_vigia'),
    [switch]$Rapido
)
$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot
New-Item -ItemType Directory -Force (Join-Path $raiz 'build'), (Join-Path $raiz 'tb\salidas') | Out-Null
if ($Rapido) { $Pruebas = $Pruebas | Where-Object { $_ -ne 'tb_vigia' } }

$iverilog = 'C:\iverilog\bin\iverilog.exe'
$vvp      = 'C:\iverilog\bin\vvp.exe'
if (-not (Test-Path $iverilog)) { $iverilog = (Get-Command iverilog).Source; $vvp = (Get-Command vvp).Source }

# el procesador (los bloques de la clase), los perifericos, la vision y el sistema completo
$hdl = @('pipo_register', 'rom', 'ram', 'regfile', 'decoder', 'alu_riscv', 'divider', 'uc_simple',
         'riscv_neura', 'perifericos', 'jtag_loader') | ForEach-Object { "hdl/$_.v" }
$hdl += @('memoria_doble_puerto', 'ram_dp', 'ram_2clk', 'cam_capture', 'block_avg', 'fondo_mascara',
          'vga_sincronia', 'vga_draw', 'pc_view', 'registros_vision', 'vision_vigia') |
        ForEach-Object { "hdl/vision/$_.v" }
$hdl += @('hdl/soc_neura32.v', 'tb/sim_jtag.v', 'prog/generador_programa.v', 'tb/modelo_ov7670.v')
$opciones = @('-g2005', '-Wall', '-Wno-sensitivity-entire-array', '-Wno-timescale', '-I', 'hdl', '-I', 'prog')

$fallo = $false
Push-Location $raiz
try {
    # la fuente de letras del monitor se lee de la carpeta desde donde se simula
    Copy-Item hdl/vision/font8x16.txt font8x16.txt -Force

    # ---- 1. los programas en hexadecimal (los mismos que se simulan y el que lee Quartus) ----
    Write-Host '== programas en hexadecimal ==' -ForegroundColor Cyan
    foreach ($n in 1..4) {
        & $iverilog -g2005 -Wno-timescale -I hdl -I prog "-Pgenerar_rom.PROGRAMA=$n" -s generar_rom `
            -o build/generar_rom.vvp prog/generador_programa.v tb/generar_rom.v
        if ($LASTEXITCODE -ne 0) { throw "iverilog fallo al armar el programa $n." }
        & $vvp -n build/generar_rom.vvp | Where-Object { $_ -notmatch '\$finish' } | ForEach-Object { Write-Host "   $_" }
    }

    # ---- 2. bancos de prueba ----
    foreach ($tb in $Pruebas) {
        Write-Host "== $tb ==" -ForegroundColor Cyan
        & $iverilog @opciones -s $tb -o "build/$tb.vvp" @hdl "tb/$tb.v"
        if ($LASTEXITCODE -ne 0) { throw "iverilog fallo con $tb." }
        $salida = & $vvp -n "build/$tb.vvp" | Where-Object { $_ -notmatch '^VCD|\$finish|^WARNING: .*readmemh' }
        $salida | ForEach-Object { Write-Host "   $_" }
        $salida | Set-Content -Encoding utf8 "tb/$tb.txt"
        if (($salida -join "`n") -notmatch 'ERRORES: 0\b') { $fallo = $true }
    }
    if ($Pruebas -contains 'tb_vigia' -or $Pruebas -contains 'tb_vision') { & python -I sw/convertir_imagenes.py }
} finally { Pop-Location }

if ($fallo) { Write-Host 'Hay discrepancias.' -ForegroundColor Red; exit 1 }
Write-Host 'Simulacion sin errores.' -ForegroundColor Green

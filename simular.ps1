<#
.SYNOPSIS
  Simula NEURA-32 Vigia con Icarus Verilog: bloques, repertorio, ROM de la clase y sistema completo.

.DESCRIPTION
  Primero genera la ROM del programa (tb/generar_rom.v -> fpga/programa_vigia.txt, la que lee Quartus).
  Despues corre los testbenches:
    tb_unidad_control       tabla de control por tipo de instruccion (Practica 5)
    tb_memoria_datos        RAM con lb/lh/lw/lbu/lhu/sb/sh/sw y extension de signo (Practica 4)
    tb_instrucciones_clase  la ROM de instrucciones de la clase (31 instrucciones) ejecutada en el procesador
    tb_prueba_isa           92 resultados: RV32IM, Zbb, clase, CSR, Xneura, riesgos y division iterativa
    tb_red_neuronal         clasificador 3x3 de la version anterior (regresion)
    tb_vigia                SoC completo + modelo de la camara OV7670: perro (sin alarma) y persona
                            (cruce prohibido e intrusion en zona). Tarda unos 10 minutos.
  Cada salida queda en tb\<tb>.txt; las imagenes de tb_vigia se convierten a PNG en docs\img.
  Sale con codigo 1 si algun testbench reporta errores.

.PARAMETER Pruebas
  Testbenches a correr (por omision todos).
.PARAMETER Rapido
  Todos menos tb_vigia.
.PARAMETER AdelantarCargas
  Compila con ADELANTAR_CARGAS=1 (sin detencion carga-uso) para comparar el CPI.

.EXAMPLE
  pwsh -File simular.ps1 -Rapido
  pwsh -File simular.ps1 -Pruebas tb_vigia
#>
param(
    [string[]]$Pruebas = @('tb_unidad_control', 'tb_memoria_datos', 'tb_instrucciones_clase',
                           'tb_prueba_isa', 'tb_red_neuronal', 'tb_vigia'),
    [switch]$Rapido,
    [switch]$AdelantarCargas
)
$ErrorActionPreference = 'Stop'
$raiz  = $PSScriptRoot
$build = Join-Path $raiz 'build'
New-Item -ItemType Directory -Force $build, (Join-Path $raiz 'tb\salidas') | Out-Null
if ($Rapido) { $Pruebas = $Pruebas | Where-Object { $_ -ne 'tb_vigia' } }

$iverilog = 'C:\iverilog\bin\iverilog.exe'
$vvp      = 'C:\iverilog\bin\vvp.exe'
if (-not (Test-Path $iverilog)) { $iverilog = (Get-Command iverilog).Source; $vvp = (Get-Command vvp).Source }

$hdl = @('alu_riscv','rom_instrucciones','ram_datos','banco_registros','generador_inmediato',
         'unidad_control','unidad_saltos','unidad_adelantamiento','unidad_riesgos',
         'unidad_acceso_memoria','divisor_iterativo','registros_csr','perifericos','nucleo_neura32') |
       ForEach-Object { "hdl/$_.v" }
$hdl += @('memoria_doble_puerto','captura_ov7670','fondo_mascara','vga_sincronia','vga_dibujo',
          'registros_vision','vision_vigia') | ForEach-Object { "hdl/vision/$_.v" }
$hdl += @('hdl/soc_neura32.v', 'prog/generador_programa.v', 'tb/modelo_ov7670.v')
$opciones = @('-g2005', '-Wall', '-Wno-sensitivity-entire-array', '-Wno-timescale', '-I', 'hdl', '-I', 'prog')

$fallo = $false
Push-Location $raiz
try {
    # ---- 1. la ROM del programa (la misma que se simula y la que lee Quartus) ----
    Write-Host '== generar_rom ==' -ForegroundColor Cyan
    & $iverilog @opciones -s generar_rom -o build/generar_rom.vvp prog/generador_programa.v tb/generar_rom.v
    if ($LASTEXITCODE -ne 0) { throw 'iverilog fallo con generar_rom.' }
    & $vvp -n build/generar_rom.vvp | Where-Object { $_ -notmatch '\$finish' } | ForEach-Object { Write-Host "   $_" }

    # ---- 2. testbenches ----
    foreach ($tb in $Pruebas) {
        Write-Host "== $tb ==" -ForegroundColor Cyan
        $args = $opciones + @('-s', $tb, '-o', "build/$tb.vvp")
        if ($AdelantarCargas -and $tb -in @('tb_prueba_isa', 'tb_red_neuronal', 'tb_vigia')) { $args += "-P$tb.ADELANTAR_CARGAS=1" }
        & $iverilog @args @hdl "tb/$tb.v"
        if ($LASTEXITCODE -ne 0) { throw "iverilog fallo con $tb." }
        $salida = & $vvp -n "build/$tb.vvp" | Where-Object { $_ -notmatch '^VCD|\$finish' }
        $salida | ForEach-Object { Write-Host "   $_" }
        $salida | Set-Content -Encoding utf8 "tb/$tb.txt"
        if (($salida -join "`n") -notmatch 'ERRORES: 0\b') { $fallo = $true }
    }
    if ($Pruebas -contains 'tb_vigia') { & python -I sw/convertir_imagenes.py }
} finally { Pop-Location }

if ($fallo) { Write-Host 'Hay discrepancias.' -ForegroundColor Red; exit 1 }
Write-Host 'Simulacion sin errores.' -ForegroundColor Green

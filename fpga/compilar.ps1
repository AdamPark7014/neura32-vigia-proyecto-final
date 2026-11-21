<#
.SYNOPSIS
  Compila NEURA-32 Vigia para la DE10-Lite con Quartus Prime 24.1 Lite y resume recursos y tiempos.

.DESCRIPTION
  Corre el flujo completo (sintesis, ajuste, ensamblado y analisis de tiempos) del proyecto vigia.qpf
  y deja en RESUMEN.txt los elementos logicos, registros, bits de memoria, multiplicadores, pines y la
  frecuencia maxima del reloj de 25 MHz. La ROM se llena con programa_vigia.txt (formato de instrucciones.txt de la
  clase), que escribe tb/generar_rom.v al correr simular.ps1.

  Correr desde una terminal normal de Windows. Desde la app de escritorio de Claude Windows bloquea
  ip-catalog.exe ("Una directiva de Control de aplicaciones bloqueo este archivo") y Quartus no elabora.

.PARAMETER Grabar
  Despues de compilar, programa la DE10-Lite por USB-Blaster (volatil: se pierde al apagar la placa).

.EXAMPLE
  pwsh -File compilar.ps1
  pwsh -File compilar.ps1 -Grabar
#>
[CmdletBinding()]
param([switch]$Grabar)

$ErrorActionPreference = 'Stop'
$raiz    = $PSScriptRoot
$quartus = 'C:\intelFPGA_lite\24.1std\quartus\bin64'
if (-not (Test-Path "$quartus\quartus_sh.exe")) { throw "No encuentro Quartus en $quartus." }
if (-not (Test-Path "$raiz\programa_vigia.txt")) { throw "Falta programa_vigia.txt: primero corre ..\simular.ps1." }

Push-Location $raiz
try {
    Write-Host 'Compilando (tarda unos minutos)...' -ForegroundColor Cyan
    & "$quartus\quartus_sh.exe" --flow compile vigia -c vigia *> compilar.log
    $ok = Select-String -Path compilar.log -Pattern 'Quartus Prime Full Compilation was successful' -Quiet
    if (-not $ok) {
        Select-String -Path compilar.log -Pattern '^Error' | Select-Object -First 15 | ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
        throw 'La compilacion fallo; detalle en compilar.log.'
    }

    # ---- resumen de recursos (reporte del Fitter) ----
    $fit = Get-Content 'output_files\vigia.fit.summary'
    $sta = Get-Content 'output_files\vigia.sta.rpt'
    $fmax = $sta | Select-String -Pattern '^\;\s*([\d\.]+) MHz\s*\;\s*([\d\.]+) MHz\s*\;\s*CLK25' | Select-Object -First 1
    $peor = $sta | Select-String -Pattern 'Slow 1200mV 85C Model Setup Summary' -Context 0, 6 | Select-Object -First 1
    $resumen = @('NEURA-32 Vigia en la DE10-Lite (10M50DAF484C7G)', '') + $fit + @('', 'Frecuencia maxima (modelo lento, 85 C):')
    if ($fmax) { $resumen += $fmax.Line } else { $resumen += '(ver output_files\vigia.sta.rpt)' }
    if ($peor) { $resumen += @('', 'Holgura de setup:') + $peor.Context.PostContext }
    $resumen | Set-Content -Encoding utf8 RESUMEN.txt
    $resumen | ForEach-Object { Write-Host "   $_" }

    if ($Grabar) {
        Write-Host 'Grabando la DE10-Lite...' -ForegroundColor Cyan
        & "$quartus\quartus_pgm.exe" -c 1 -m JTAG -o 'p;output_files/vigia.sof@1'
        if ($LASTEXITCODE -ne 0) { throw 'quartus_pgm fallo (revisa el cable USB-Blaster).' }
    }
} finally { Pop-Location }
Write-Host 'Listo.' -ForegroundColor Green

[CmdletBinding()]
param([switch]$Grabar)

$ErrorActionPreference = 'Stop'
$raiz    = $PSScriptRoot
$quartus = 'C:\intelFPGA_lite\24.1std\quartus\bin64'
if (-not (Test-Path "$quartus\quartus_sh.exe")) { throw "No encuentro Quartus en $quartus." }
if (-not (Test-Path "$raiz\programa_vigia.txt")) { throw "Falta programa_vigia.txt: primero corre ..\simular.ps1." }

Push-Location $raiz
try {
    Copy-Item ..\hdl\vision\font8x16.txt font8x16.txt -Force
    Write-Host 'Compilando (tarda unos minutos)...' -ForegroundColor Cyan
    & "$quartus\quartus_sh.exe" --flow compile vigia -c vigia *> compilar.log
    $ok = Select-String -Path compilar.log -Pattern 'Quartus Prime Full Compilation was successful' -Quiet
    if (-not $ok) {
        Select-String -Path compilar.log -Pattern '^Error' | Select-Object -First 15 | ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
        throw 'La compilacion fallo; detalle en compilar.log.'
    }

    # resumen de recursos
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

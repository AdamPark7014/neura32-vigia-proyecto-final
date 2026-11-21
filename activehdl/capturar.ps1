# Captura de pantalla de la ventana de Active-HDL (resolucion nativa) a PNG.
# Usa PrintWindow, asi sale la ventana completa aunque otra la tape.
# Uso: pwsh -File capturar.ps1 -Nombre 01-panorama
param(
    [Parameter(Mandatory)] [string] $Nombre,
    [string] $Carpeta = (Join-Path $PSScriptRoot '..\docs\img')
)

Add-Type -AssemblyName System.Drawing
Add-Type -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern uint GetDpiForSystem();
public struct RECT { public int Left, Top, Right, Bottom; }
'@ -Name W -Namespace Cap

[Cap.W]::SetProcessDPIAware() | Out-Null
$p = Get-Process avhdl_core -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$h = $p.MainWindowHandle

$r = New-Object Cap.W+RECT
[Cap.W]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $hgt = $r.Bottom - $r.Top

$bmp = New-Object System.Drawing.Bitmap $w, $hgt
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[Cap.W]::PrintWindow($h, $hdc, 2) | Out-Null      # 2 = PW_RENDERFULLCONTENT
$g.ReleaseHdc($hdc)

# Active-HDL no escala por DPI: PrintWindow la dibuja a tamano logico
# (fisico / escala de Windows). Ademas, maximizada se sale unos pixeles de la
# pantalla por cada lado: se recorta ese borde.
$escala = [Cap.W]::GetDpiForSystem() / 96.0
$wl = [int][Math]::Round($w / $escala); $hl = [int][Math]::Round($hgt / $escala)
$borde = 0
if ($r.Left -lt 0) { $borde = [int][Math]::Round(-$r.Left / $escala) }
$recorte = New-Object System.Drawing.Rectangle $borde, $borde, ($wl - 2*$borde), ($hl - 2*$borde)
$final = $bmp.Clone($recorte, $bmp.PixelFormat)

New-Item -ItemType Directory -Force $Carpeta | Out-Null
$ruta = Join-Path (Resolve-Path $Carpeta) "$Nombre.png"
$final.Save($ruta, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $final.Dispose()
"{0}  {1}x{2}" -f $ruta, $recorte.Width, $recorte.Height

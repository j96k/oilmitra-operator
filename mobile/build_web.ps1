# Builds the three OilMitra web apps with Google Maps and copies them into
# backend\webapp (supplier /app/), backend\admin_webapp (operator /admin/) and
# backend\portal_webapp (myOilMitra /portal/).
#
# The Google Maps JavaScript API key is NOT baked into these bundles. The web
# page asks the backend for it at runtime (GET /geo/config), so the committed
# bundles never contain a key. On Render, set GOOGLE_MAPS_API_KEY on each
# service (and enable Maps JavaScript API + billing on the key).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File mobile\build_web.ps1

param(
    [string]$ApiUrl = '',
    [string[]]$Apps = @('supplier', 'operator', 'portal')
)

$ErrorActionPreference = 'Stop'

$mobile = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path -Parent $mobile
$flutter = 'F:\rental_cloth_management\flutter\bin\flutter.bat'
$env:PUB_CACHE = Join-Path $repo '.pub-cache'

$defines = @('--dart-define=MAPS_PROVIDER=google')
if ($ApiUrl) { $defines += "--dart-define=API_URL=$ApiUrl" }

$builds = @{
    supplier = @{
        Args = @('build', 'web', '--base-href', '/app/', '--output', 'build/web') + $defines
        Out  = 'build\web'
        Dest = Join-Path $repo 'backend\webapp'
    }
    operator = @{
        Args = @('build', 'web', '--target', 'lib/main_admin.dart', '--base-href', '/admin/', '--output', 'build/admin_web') + $defines
        Out  = 'build\admin_web'
        Dest = Join-Path $repo 'backend\admin_webapp'
    }
    portal   = @{
        Args = @('build', 'web', '--target', 'lib/main_myoilmitra.dart', '--base-href', '/portal/', '--output', 'build/portal_web') + $defines
        Out  = 'build\portal_web'
        Dest = Join-Path $repo 'backend\portal_webapp'
    }
}

foreach ($app in $Apps) {
    if (-not $builds.ContainsKey($app)) { throw "Unknown app '$app' (use supplier, operator, portal)." }
    $b = $builds[$app]

    Write-Host ''
    Write-Host "==> Building $app web"
    Push-Location $mobile
    try {
        & $flutter @($b.Args)
        if ($LASTEXITCODE -ne 0) { throw "flutter build web failed for $app" }
    } finally {
        Pop-Location
    }

    $src = Join-Path $mobile $b.Out
    if (-not (Test-Path (Join-Path $src 'index.html'))) { throw "Web build missing: $src" }
    if (Test-Path $b.Dest) { Remove-Item -Recurse -Force $b.Dest }
    New-Item -ItemType Directory -Force -Path $b.Dest | Out-Null
    Copy-Item -Recurse -Force (Join-Path $src '*') $b.Dest
    Write-Host "    -> $($b.Dest)"
}

Write-Host ''
Write-Host 'Done. All three web apps use Google Maps (key served by /geo/config).'

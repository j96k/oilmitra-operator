# Builds the OilMitra Android APKs with Google Maps.
#
# The Google key is required and is injected into AndroidManifest.xml at build
# time (never written to source files). Read from, in order:
#   1. -ApiKey "AIza..."
#   2. $env:GOOGLE_MAPS_API_KEY
#   3. ..\backend\.env                    (GOOGLE_MAPS_API_KEY=...)
#   4. android\local.properties           (GOOGLE_MAPS_API_KEY=...)
#
# Google Cloud must have billing enabled and these APIs on the key:
#   Maps SDK for Android, Geocoding API.
#
# Output: F:\OilMitra\mobile\build\app\outputs\flutter-apk\
#   OilMitra-Supplier-1.0.0.apk
#   OilMitra-Operator-1.0.0.apk
#   myOilMitra-1.0.0.apk

param(
    [string]$ApiKey = '',
    [string]$ApiUrl = 'https://oilmitra.onrender.com',
    [string[]]$Apps = @('supplier', 'operator', 'myoilmitra'),
    # Appended to the copied APK name, e.g. -Tag '-test' -> OilMitra-Supplier-1.0.0-test.apk
    [string]$Tag = ''
)

$ErrorActionPreference = 'Stop'

$mobile = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path -Parent $mobile
$flutter = 'F:\rental_cloth_management\flutter\bin\flutter.bat'
$builtDir = Join-Path $mobile 'build\app\outputs\flutter-apk'
$env:PUB_CACHE = Join-Path $repo '.pub-cache'

function Read-Prop([string]$path, [string]$name) {
    if (-not (Test-Path $path)) { return '' }
    $m = Select-String -Path $path -Pattern "^\s*$([regex]::Escape($name))\s*=\s*(.*)$" | Select-Object -First 1
    if ($m) { return ($m.Matches[0].Groups[1].Value.Trim() -replace '\\\\', '\') }
    return ''
}

function Read-KeyFromFile([string]$path) {
    return Read-Prop $path 'GOOGLE_MAPS_API_KEY'
}

# The Flutter tool needs a valid ANDROID_HOME. Prefer the SDK recorded in
# android/local.properties (the machine-wide env var may point at a stale path).
$sdk = Read-Prop (Join-Path $mobile 'android\local.properties') 'sdk.dir'
if ($sdk -and (Test-Path $sdk)) {
    $env:ANDROID_HOME = $sdk
    $env:ANDROID_SDK_ROOT = $sdk
}
if (-not $env:ANDROID_HOME -or -not (Test-Path $env:ANDROID_HOME)) {
    throw "Android SDK not found. Set sdk.dir in mobile\android\local.properties or set ANDROID_HOME."
}

function Get-GoogleKey {
    if ($ApiKey) { return $ApiKey.Trim() }
    if ($env:GOOGLE_MAPS_API_KEY) { return $env:GOOGLE_MAPS_API_KEY.Trim() }
    $k = Read-KeyFromFile (Join-Path $repo 'backend\.env')
    if ($k) { return $k }
    $k = Read-KeyFromFile (Join-Path $mobile 'android\local.properties')
    if ($k) { return $k }
    return ''
}

$key = Get-GoogleKey
if (-not $key) {
    throw 'No Google Maps key found. Put GOOGLE_MAPS_API_KEY=... in backend\.env or android\local.properties, or pass -ApiKey.'
}
$env:GOOGLE_MAPS_API_KEY = $key
Write-Host "Google Maps: ON (key length $($key.Length))"

$targets = @{
    supplier   = @{ Target = 'lib/main.dart';            Out = 'OilMitra-Supplier-1.0.0.apk' }
    operator   = @{ Target = 'lib/main_admin.dart';      Out = 'OilMitra-Operator-1.0.0.apk' }
    myoilmitra = @{ Target = 'lib/main_myoilmitra.dart'; Out = 'myOilMitra-1.0.0.apk' }
}

foreach ($app in $Apps) {
    if (-not $targets.ContainsKey($app)) { throw "Unknown app '$app' (use supplier, operator, myoilmitra)." }
    $t = $targets[$app]

    $buildArgs = @(
        'build', 'apk', '--release',
        '--flavor', $app,
        '--target', $t.Target,
        "--dart-define=API_URL=$ApiUrl",
        '--dart-define=MAPS_PROVIDER=google',
        "--dart-define=GOOGLE_MAPS_API_KEY=$key"
    )

    Write-Host ''
    Write-Host "==> Building $app ($($t.Target))"
    & $flutter @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed for $app" }

    $outName = $t.Out
    if ($Tag) {
        $outName = [System.IO.Path]::GetFileNameWithoutExtension($t.Out) + $Tag + [System.IO.Path]::GetExtension($t.Out)
    }
    $built = Join-Path $builtDir "app-$app-release.apk"
    if (-not (Test-Path $built)) { throw "APK not found: $built" }
    # Keep a properly named copy next to Flutter's raw output:
    #   F:\OilMitra\mobile\build\app\outputs\flutter-apk\<name>.apk
    Copy-Item -Force $built (Join-Path $builtDir $outName)
    $mb = [math]::Round((Get-Item $built).Length / 1MB, 1)
    Write-Host "    -> build\app\outputs\flutter-apk\$outName ($mb MB)"
}

Write-Host ''
Write-Host 'Done.'

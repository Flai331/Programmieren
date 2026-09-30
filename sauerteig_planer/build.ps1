# Sauerteig Planer – Build-Skript
# Verwendung: .\build.ps1            → Debug-APK
#             .\build.ps1 release    → Release-APK
#             .\build.ps1 run        → flutter run

$file = "lib\build_info.dart"
$content = Get-Content $file -Raw
$content -match 'kBuildNumber = (\d+)' | Out-Null
$current = [int]$Matches[1]
$next = $current + 1

$newContent = $content -replace "kBuildNumber = $current", "kBuildNumber = $next"
Set-Content $file $newContent -NoNewline

Write-Host "Build $next" -ForegroundColor Cyan

switch ($args[0]) {
    "release" { flutter build apk --release }
    "run"     { flutter run }
    default   { flutter build apk --debug }
}

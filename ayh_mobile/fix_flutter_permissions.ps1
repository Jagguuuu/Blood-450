# Run this script as Administrator to fix Flutter permission issues
# Right-click PowerShell and select "Run as Administrator", then run this script

Write-Host "Adding Windows Defender exclusions for Flutter..." -ForegroundColor Green

# Add Flutter SDK exclusion
$flutterPath = "$env:USERPROFILE\.android\flutter"
if (Test-Path $flutterPath) {
    Add-MpPreference -ExclusionPath $flutterPath
    Write-Host "Added exclusion: $flutterPath" -ForegroundColor Cyan
}

# Add Pub Cache exclusions
$pubCachePaths = @(
    "$env:USERPROFILE\.pub-cache",
    "$env:LOCALAPPDATA\Pub\Cache",
    "$env:APPDATA\Pub\Cache"
)

foreach ($path in $pubCachePaths) {
    if (Test-Path $path) {
        Add-MpPreference -ExclusionPath $path
        Write-Host "Added exclusion: $path" -ForegroundColor Cyan
    }
}

# Add project folder exclusion
$projectPath = "$env:USERPROFILE\Downloads\blood-450-main\blood-450-main\blood-450-main\ayh_mobile"
if (Test-Path $projectPath) {
    Add-MpPreference -ExclusionPath $projectPath
    Write-Host "Added exclusion: $projectPath" -ForegroundColor Cyan
}

Write-Host "`nExclusions added successfully!" -ForegroundColor Green
Write-Host "Now try running: flutter pub get" -ForegroundColor Yellow

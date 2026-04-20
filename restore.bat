@echo off
chcp 65001 >nul
set "SELF=%~f0"
set LT=^<
set GT=^>
powershell -NoProfile -ExecutionPolicy Bypass -Command "try{$f=[System.IO.File]::ReadAllText($env:SELF);$m=$env:LT+'#PS1#'+$env:GT;$i=$f.IndexOf($m);if($i-lt 0){throw 'Marker not found'};$f=$f.Substring($i+$m.Length);$n=$f.IndexOf([char]10);$f=$f.Substring($n+1);$e=$env:LT+'#END#'+$env:GT;$f=$f.Substring(0,$f.IndexOf($e));Invoke-Expression $f}catch{Write-Host ('Bootstrap error: '+$_) -ForegroundColor Red;Read-Host 'Press Enter'}"
goto :eof
<#PS1#>
$ErrorActionPreference = 'Stop'
try {
    $chromePaths = [ordered]@{
        'Stable' = "$env:LOCALAPPDATA\Google\Chrome\User Data"
        'Canary' = "$env:LOCALAPPDATA\Google\Chrome SxS\User Data"
        'Dev'    = "$env:LOCALAPPDATA\Google\Chrome Dev\User Data"
        'Beta'   = "$env:LOCALAPPDATA\Google\Chrome Beta\User Data"
    }

    $runningChromes = @()
    Get-Process -Name 'chrome' -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $exe = $_.MainModule.FileName
            if ($exe -and ($runningChromes -notcontains $exe)) {
                $runningChromes += $exe
            }
        } catch {}
    }

    if ($runningChromes.Count -gt 0) {
        Stop-Process -Name 'chrome' -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Write-Host "Chrome stopped."
    }

    $anyFound = $false
    foreach ($entry in $chromePaths.GetEnumerator()) {
        $name = $entry.Key
        $userDataPath = $entry.Value
        if (-not (Test-Path $userDataPath)) { continue }

        $localStatePath = Join-Path $userDataPath 'Local State'
        $backupPath = "$localStatePath.backup"

        if (-not (Test-Path $backupPath)) {
            Write-Host "[$name] No backup found, skipping."
            continue
        }
        $anyFound = $true

        Copy-Item $backupPath $localStatePath -Force
        Write-Host "[$name] Restored from backup."
    }

    if (-not $anyFound) {
        Write-Host "No backup found. Run enable.bat first."
    }

    foreach ($exe in $runningChromes) {
        Start-Process $exe
    }
    if ($runningChromes.Count -gt 0) {
        Write-Host "Chrome restarted."
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Read-Host "Press Enter to exit"
<#END#>

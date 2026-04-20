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

    function Set-GlicEligible {
        param($obj)
        $modified = $false
        if ($obj -is [PSCustomObject]) {
            foreach ($prop in @($obj.PSObject.Properties)) {
                if ($prop.Name -eq 'is_glic_eligible') {
                    if ($prop.Value -ne $true) {
                        $obj.($prop.Name) = $true
                        $modified = $true
                    }
                } elseif ($prop.Value -is [PSCustomObject] -or $prop.Value -is [Object[]]) {
                    if (Set-GlicEligible $prop.Value) { $modified = $true }
                }
            }
        } elseif ($obj -is [Object[]]) {
            foreach ($item in $obj) {
                if (Set-GlicEligible $item) { $modified = $true }
            }
        }
        return $modified
    }

    $anyFound = $false
    foreach ($entry in $chromePaths.GetEnumerator()) {
        $name = $entry.Key
        $userDataPath = $entry.Value
        if (-not (Test-Path $userDataPath)) { continue }
        $anyFound = $true

        $localStatePath = Join-Path $userDataPath 'Local State'
        $lastVersionPath = Join-Path $userDataPath 'Last Version'
        $backupPath = "$localStatePath.backup"

        if (-not (Test-Path $localStatePath)) {
            Write-Host "[$name] Local State not found. Launch Chrome once first."
            continue
        }

        $lastVersion = if (Test-Path $lastVersionPath) { (Get-Content $lastVersionPath -Raw).Trim() } else { '' }

        Copy-Item $localStatePath $backupPath -Force
        Write-Host "[$name] Backed up Local State"

        $json = Get-Content $localStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $modified = $false

        if (Set-GlicEligible $json) {
            $modified = $true
            Write-Host "[$name] Patched is_glic_eligible"
        }

        if ($json.variations_country -ne 'us') {
            $json | Add-Member -MemberType NoteProperty -Name 'variations_country' -Value 'us' -Force
            $modified = $true
            Write-Host "[$name] Patched variations_country"
        }

        $vpcc = $json.variations_permanent_consistency_country
        if ($null -ne $vpcc -and $vpcc -is [Object[]] -and $vpcc.Count -ge 2) {
            if ($vpcc[0] -ne $lastVersion -or $vpcc[1] -ne 'us') {
                $vpcc[0] = $lastVersion
                $vpcc[1] = 'us'
                $modified = $true
                Write-Host "[$name] Patched variations_permanent_consistency_country"
            }
        }

        if ($modified) {
            $content = $json | ConvertTo-Json -Depth 100 -Compress
            [System.IO.File]::WriteAllText($localStatePath, $content, [System.Text.UTF8Encoding]::new($false))
            Write-Host "[$name] Done."
        } else {
            Write-Host "[$name] No changes needed."
        }
    }

    if (-not $anyFound) {
        Write-Host "No Chrome installation found."
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

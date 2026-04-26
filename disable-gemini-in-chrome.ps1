# ChromeAI 無効化（元に戻す）スクリプト (PowerShell版 修正版)

# Chromeのユーザーデータパスの定義
$userDataPaths = @{
    "stable" = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    "canary" = "$env:LOCALAPPDATA\Google\Chrome SxS\User Data"
    "dev"    = "$env:LOCALAPPDATA\Google\Chrome Dev\User Data"
    "beta"   = "$env:LOCALAPPDATA\Google\Chrome Beta\User Data"
}

# 1. 実行中のChromeプロセスを取得して終了
$executablePaths = @()
$chromeProcesses = Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'"

foreach ($proc in $chromeProcesses) {
    if ($proc.ExecutablePath -and $executablePaths -notcontains $proc.ExecutablePath) {
        $executablePaths += $proc.ExecutablePath
    }
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
}

if ($executablePaths.Count -gt 0) {
    Write-Host "Shutdown Chrome."
    Start-Sleep -Seconds 2
}

# JSON内の is_glic_eligible を再帰的に false に変更する関数
function Revert-GlicEligible($obj) {
    if ($null -eq $obj) { return $false }
    $modified = $false

    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $obj.psobject.Properties) {
            # true になっているものを false に戻す
            if ($prop.Name -eq 'is_glic_eligible' -and $prop.Value -eq $true) {
                $prop.Value = $false
                $modified = $true
            } elseif ($prop.Value -is [System.Management.Automation.PSCustomObject] -or $prop.Value -is [System.Collections.IEnumerable]) {
                if (Revert-GlicEligible $prop.Value) {
                    $modified = $true
                }
            }
        }
    } elseif ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
        foreach ($item in $obj) {
            if (Revert-GlicEligible $item) {
                $modified = $true
            }
        }
    }
    return $modified
}

# 2. 各Chromeバージョンの Local State ファイルを元に戻す
foreach ($key in $userDataPaths.Keys) {
    $userDataPath = $userDataPaths[$key]
    
    if (Test-Path $userDataPath) {
        $localStateFile = Join-Path $userDataPath "Local State"
        if (-not (Test-Path $localStateFile)) {
            continue
        }

        Write-Host "Reverting Chrome $key `"$userDataPath`""

        # JSONファイルの読み込み（-Depth を削除）
        $jsonString = [System.IO.File]::ReadAllText($localStateFile, [System.Text.Encoding]::UTF8)
        $localState = $jsonString | ConvertFrom-Json

        $modified = $false

        # ① is_glic_eligible の無効化
        if (Revert-GlicEligible $localState) {
            $modified = $true
            Write-Host "  -> Reverted is_glic_eligible"
        }

        # ② variations_country の削除（Chromeに再設定させる）
        if ($null -ne $localState.psobject.properties['variations_country']) {
            $localState.psobject.properties.Remove('variations_country')
            $modified = $true
            Write-Host "  -> Removed variations_country"
        }

        # ③ variations_permanent_consistency_country の削除（Chromeに再設定させる）
        if ($null -ne $localState.psobject.properties['variations_permanent_consistency_country']) {
            $localState.psobject.properties.Remove('variations_permanent_consistency_country')
            $modified = $true
            Write-Host "  -> Removed variations_permanent_consistency_country"
        }

        # 変更があった場合のみ保存 (ConvertTo-Json には -Depth 100 を残す)
        if ($modified) {
            $newJsonString = $localState | ConvertTo-Json -Depth 100 -Compress
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($localStateFile, $newJsonString, $utf8NoBom)
            Write-Host "Successfully reverted Local State for $key"
        } else {
            Write-Host "No changes needed for $key"
        }
    }
}

# 3. 終了したChromeを再起動
if ($executablePaths.Count -gt 0) {
    Write-Host "Restart Chrome..."
    foreach ($exe in $executablePaths) {
        Start-Process -FilePath $exe
    }
}

Write-Host ""
Read-Host "Enter to continue..."
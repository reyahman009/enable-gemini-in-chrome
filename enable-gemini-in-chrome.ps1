# ChromeAI 有効化スクリプト (PowerShell 5.1 対応修正版)

# Chromeのユーザーデータパスの定義
$userDataPaths = @{
    "stable" = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    "canary" = "$env:LOCALAPPDATA\Google\Chrome SxS\User Data"
    "dev"    = "$env:LOCALAPPDATA\Google\Chrome Dev\User Data"
    "beta"   = "$env:LOCALAPPDATA\Google\Chrome Beta\User Data"
}

# 1. 実行中のChromeプロセスを取得して終了し、実行ファイルのパスを記録
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
    Start-Sleep -Seconds 2 # ファイルロック解除のための待機
}

# JSON内の is_glic_eligible を再帰的に true に変更する関数
function Update-GlicEligible($obj) {
    if ($null -eq $obj) { return $false }
    $modified = $false

    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $obj.psobject.Properties) {
            if ($prop.Name -eq 'is_glic_eligible' -and $prop.Value -ne $true) {
                $prop.Value = $true
                $modified = $true
            } elseif ($prop.Value -is [System.Management.Automation.PSCustomObject] -or $prop.Value -is [System.Collections.IEnumerable]) {
                if (Update-GlicEligible $prop.Value) {
                    $modified = $true
                }
            }
        }
    } elseif ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
        foreach ($item in $obj) {
            if (Update-GlicEligible $item) {
                $modified = $true
            }
        }
    }
    return $modified
}

# 2. 各Chromeバージョンの Local State ファイルをパッチング
foreach ($key in $userDataPaths.Keys) {
    $userDataPath = $userDataPaths[$key]
    
    if (Test-Path $userDataPath) {
        $lastVersionFile = Join-Path $userDataPath "Last Version"
        if (-not (Test-Path $lastVersionFile)) {
            continue
        }

        $lastVersion = (Get-Content $lastVersionFile -Raw).Trim()
        Write-Host "Patching Chrome $key $lastVersion `"$userDataPath`""

        $localStateFile = Join-Path $userDataPath "Local State"
        if (-not (Test-Path $localStateFile)) {
            Write-Host "Failed to patch Local State. File not found: $localStateFile"
            continue
        }

        # JSONファイルの読み込み (-Depth を削除して PS 5.1 に対応)
        $jsonString = [System.IO.File]::ReadAllText($localStateFile, [System.Text.Encoding]::UTF8)
        $localState = $jsonString | ConvertFrom-Json

        $modified = $false

        # ① is_glic_eligible の書き換え
        if (Update-GlicEligible $localState) {
            $modified = $true
            Write-Host "  -> Patched is_glic_eligible"
        }

        # ② variations_country の書き換え
        if ($localState.variations_country -ne 'us') {
            if ($null -eq $localState.psobject.properties['variations_country']) {
                $localState | Add-Member -MemberType NoteProperty -Name "variations_country" -Value "us"
            } else {
                $localState.variations_country = 'us'
            }
            $modified = $true
            Write-Host "  -> Patched variations_country"
        }

        # ③ variations_permanent_consistency_country の書き換え
        if ($null -ne $localState.psobject.properties['variations_permanent_consistency_country']) {
            if ($localState.variations_permanent_consistency_country.Count -ge 2) {
                if ($localState.variations_permanent_consistency_country[0] -ne $lastVersion -or $localState.variations_permanent_consistency_country[1] -ne 'us') {
                    $localState.variations_permanent_consistency_country[0] = $lastVersion
                    $localState.variations_permanent_consistency_country[1] = 'us'
                    $modified = $true
                    Write-Host "  -> Patched variations_permanent_consistency_country"
                }
            }
        }

        # 変更があった場合のみ保存 (ConvertTo-Json には -Depth 100 が必須)
        if ($modified) {
            # JSON文字列への変換 (BOMなしUTF-8で保存)
            $newJsonString = $localState | ConvertTo-Json -Depth 100 -Compress
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($localStateFile, $newJsonString, $utf8NoBom)
            Write-Host "Successfully patched Local State for $key"
        } else {
            Write-Host "No need to patch Local State for $key"
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
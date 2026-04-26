# Enable Gemini in Chrome (Windows)

## これは何？

2026年4月20日現在、**Gemini in Chrome は日本国内の Windows 版 Chrome では利用できません。**

このプログラムは、Chrome の設定ファイルを書き換えることで、日本国内でも Gemini in Chrome を強制的に有効化するための Windows 用 PowerShell スクリプトです。

## 有効になる機能

- Gemini in Chrome（ブラウザ内AI）
- AIによる履歴検索
- DevTools AIイノベーション

## 使い方

### 事前準備

Chrome を一度起動してから閉じておいてください。  
（一度も起動していない場合、設定ファイルが存在せず動作しません）

### 有効化

1. **`enable-gemini-in-chrome.ps1`** を右クリックし、「PowerShell で実行」を選択します
2. Chrome が自動的に終了します（開いていたタブは再起動後に復元されます）
3. 設定ファイルが書き換えられ、Chrome が自動的に再起動します
4. `Enter to continue...` と表示されたら Enter を押して完了です

> **注意:** 実行中に Chrome が一度閉じます。作業中のタブがある場合は先に保存してください。

```
Shutdown Chrome.
Patching Chrome stable "C:\Users\...\Google\Chrome\User Data"
  -> Patched is_glic_eligible
  -> Patched variations_country
  -> Patched variations_permanent_consistency_country
Successfully patched Local State for stable
Restart Chrome...

Enter to continue...:
```

### 元に戻す

1. **`disable-gemini-in-chrome.ps1`** を右クリックし、「PowerShell で実行」を選択します
2. Chrome が自動的に終了・再起動し、変更した設定値が元に戻ります

```
Shutdown Chrome.
Reverting Chrome stable "C:\Users\...\Google\Chrome\User Data"
  -> Reverted is_glic_eligible
  -> Removed variations_country
  -> Removed variations_permanent_consistency_country
Successfully reverted Local State for stable
Restart Chrome...

Enter to continue...:
```

### 実行できない場合（セキュリティエラー）

PowerShell のスクリプト実行ポリシーによってブロックされる場合があります。  
その場合は、PowerShell を開いて以下のコマンドを実行してから再試行してください。

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

または、ファイルを右クリック → プロパティ → 「ブロックの解除」にチェックを入れてOKをクリックしてください。

## 動作の仕組み

### 有効化（enable-gemini-in-chrome.ps1）

Chrome の `Local State` ファイル内にある以下の値を書き換えることで AI 機能を有効化します。

- `is_glic_eligible` — Gemini 利用資格フラグ → `true`
- `variations_country` — 国設定 → `"us"`
- `variations_permanent_consistency_country` — 永続的な国設定 → `["バージョン番号", "us"]`

### 無効化（disable-gemini-in-chrome.ps1）

変更した値をそれぞれ元の状態に戻します。

- `is_glic_eligible` → `false`
- `variations_country` → 削除（Chrome が再設定）
- `variations_permanent_consistency_country` → 削除（Chrome が再設定）

## 対応 Chrome バリアント

- Stable
- Canary
- Dev
- Beta

インストールされているすべてのバリアントを自動で検出し、まとめて処理します。

## 注意事項

- Google の公式機能ではありません。自己責任でご利用ください。
- **実行中に Chrome が一度閉じます。** 作業中のタブは事前に保存してください。
- Chrome を一度起動して設定ファイルを生成してから実行してください。

## 参考

- [enable-chrome-ai](enable-chrome-ai/) — 同等機能の Python スクリプト版

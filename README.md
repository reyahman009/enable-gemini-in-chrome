# Enable Gemini in Chrome (Windows)

ChromeのビルトインAI機能（Gemini）をWindowsで有効化するバッチスクリプトです。

## 有効になる機能

- Gemini in Chrome（ブラウザ内AI）
- AIによる履歴検索
- DevTools AIイノベーション

## 使い方

### 事前準備

Chromeを一度起動してから閉じておいてください。  
（一度も起動していない場合、設定ファイルが存在せず動作しません）

### 有効化

1. **`enable.bat`** をダブルクリックして実行します
2. Chromeが自動的に終了します（開いていたタブは再起動後に復元されます）
3. 設定ファイルが書き換えられ、Chromeが自動的に再起動します
4. `Press Enter to exit` と表示されたら Enter を押して完了です

> **注意:** 実行中にChromeが一度閉じます。作業中のタブがある場合は先に保存してください。

```
Chrome stopped.
[Stable] Backed up Local State
[Stable] Patched is_glic_eligible
[Stable] Patched variations_country
[Stable] Patched variations_permanent_consistency_country
[Stable] Done.
Chrome restarted.
Press Enter to exit:
```

### 元に戻す

1. **`restore.bat`** をダブルクリックして実行します
2. Chromeが自動的に終了・再起動し、設定が元に戻ります

> **注意:** `enable.bat` を実行済みの場合のみ動作します。

```
Chrome stopped.
[Stable] Restored from backup.
Chrome restarted.
Press Enter to exit:
```

## 動作の仕組み

Chromeのプロファイルデータ（`Local State`）を直接書き換えることでAI機能を有効化します。

| 書き換える値 | 内容 |
|---|---|
| `is_glic_eligible` | Gemini利用資格フラグ → `true` |
| `variations_country` | 国設定 → `"us"` |
| `variations_permanent_consistency_country` | 永続的な国設定 → `"us"` |

実行前に `Local State.backup` としてバックアップを自動保存するため、`restore.bat` でいつでも元に戻せます。

## 対応Chromeバリアント

- Stable
- Canary
- Dev
- Beta

## 注意事項

- Googleの公式機能ではありません。自己責任でご利用ください。
- **実行中にChromeが一度閉じます。** 作業中のタブは事前に保存してください。
- Chromeを一度起動して設定ファイルを生成してから実行してください。

## 参考

- [enable-chrome-ai](enable-chrome-ai/) — 同等機能のPythonスクリプト版

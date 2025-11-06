# Charybdis ZMK Config (config-only repo)

最小 & 再現性重視の Charybdis 用 ZMK 設定。ソース本体(ZMK/Zephyr)は `west.yml` で取得し、このリポジトリには設定/レイアウト/キーマップのみを保持します。

## 特徴
* Overlay 分割廃止 → `charybdis.dtsi` に統合 (左右差分は最小 overlay)
* 行列配線と論理配置を分離する `zmk,matrix-transform` 採用 (GPIO 並び変更不要で論理入替可)
* Trackball (PMW3610) 拡張を段階的に追加可能なレイヤ構造
* `settings_reset` UF2 を標準ビルドに含め、NVS キャッシュ破損/設定変更時のクリーン適用を容易化
* Legacy `&mkp` クリック動作を標準 `MS_BTN1/2` に統一

## 現状ステータス (2025-11)
| 項目 | 状態 |
|------|------|
| シールド統合 | 完了 |
| keymap 4 レイヤ | 完了 |
| &mkp 廃止 | 完了 |
| settings_reset 同梱 | 完了 |
| ポインタ processor dtsi | (後続強化余地) |

詳細は `spec.md` を参照。

## 前提ツールインストール
west 未インストールのため初回ビルド失敗 (code 127)。以下で導入:

```bash
python3 -m pip install --user west
export PATH="$HOME/.local/bin:$PATH"  # 必要ならシェルに追加
```

## ビルド方法

### 推奨: CI環境と同一のDockerビルド
GitHub ActionsのCI環境と同じDockerコンテナを使ったビルド:

```bash
# 全ターゲットビルド (left, right, settings_reset)
./build-local-ci.sh all

# 特定ターゲットのみビルド
./build-local-ci.sh charybdis_left
./build-local-ci.sh charybdis_right
./build-local-ci.sh settings_reset

# 開発用詳細ログでビルド
LOG_PROFILE=dev ./build-local-ci.sh all
```

生成されたUF2ファイルは `build-output/` に配置されます。

**利点:**
- CIと完全に同じ環境でビルド（ツールチェーンバージョンの一致保証）
- ローカル環境を汚さない（Dockerコンテナ内で完結）
- west/toolchainのインストール不要

### 手動ローカルビルド (従来方式)
westを直接使用する場合:

```bash
west init -l .
west update
west zephyr-export

# 左 UF2
west build -s zmk/app -b nice_nano_v2 -d build/left  -- -DSHIELD=charybdis_left  -DZMK_CONFIG=$PWD/config
cp build/left/zephyr/zmk.uf2 firmware_charybdis_left.uf2

# 右 UF2 (central)
west build -s zmk/app -b nice_nano_v2 -d build/right -p -- -DSHIELD=charybdis_right -DZMK_CONFIG=$PWD/config
cp build/right/zephyr/zmk.uf2 firmware_charybdis_right.uf2

# settings_reset (必要時)
west build -s zmk/app -b nice_nano_v2 -d build/reset -p -- -DSHIELD=settings_reset -DZMK_CONFIG=$PWD/config
cp build/reset/zephyr/zmk.uf2 firmware_settings_reset.uf2
```

### matrix-transform 変更手順
1. 物理配線順 (col/row-gpios) は触らない
2. `charybdis.dtsi` の `default_transform.map` 内 RC(r,c) 順序を入替
3. ビルド & フラッシュ
4. 反応しないキーがあれば `row-gpios` 並びと transform の行入替ミスを再確認
5. 大幅変更時は一度 `settings_reset` をフラッシュ

### GitHub Actions 自動ビルド
リポジトリにpush後、Actions タブから自動生成された `.uf2` をダウンロード可能。

`build.yaml` で定義されたビルドターゲット:
- `nice_nano_v2` + `charybdis_left`
- `nice_nano_v2` + `charybdis_right`  
- `nice_nano_v2` + `settings_reset`

#### CI環境について
公式ZMKビルドコンテナ `ghcr.io/zmkfirmware/zmk-build-arm:stable` を使用。Python, west, toolchain, CMake, Ninja等は全て同梱済み。

`workflow_dispatch` で `log_profile=dev` を指定することで (将来 CMake 拡張後) 開発向け詳細ログビルドを生成予定。

## バージョン固定
ZMK & PMW3610 driver revisions pinned:
```
zmk: 4ec69cb7e658590adf6354027aca789b364a70c5 (main @ 2025-10-30)
pmw3610 driver: 1d9c2c68ca76012e1b1e5f6ef02fa5eadc4ca399 (main @ 2025-10-30)
```
Pin理由: 再現性確保 / 上流 API 変更による差分吸収をコントロール。

## settings_reset を使うタイミング
以下のケースで通常ファーム前に一度 flash:
* 行列サイズや transform の大掛かりな並び替え
* ポインタ processor ノード名/構成変更
* Bluetooth ペアリング情報の不整合 (接続不可時)

## 既知の注意点
* `pixart` ベンダープレフィックス警告は上流 prefix ファイル統合で解消予定
* 行列入替は transform で行う (GPIO 並び変更は最終手段)

---
Author: Charybdis Config Maintainers

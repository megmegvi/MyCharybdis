# modern-zmk-config (Charybdis 4x6)

グリーンフィールド再構築用 ZMK 設定ディレクトリ。

## 目的
- 公式 ZMK main をベースに最小限の Charybdis トラックボール対応を導入。
- PMW3610 センサ + input processors を段階的に統合。

## 現状ステータス
- ディレクトリ初期化のみ。後続で west.yml, shield, pointer dtsi, keymap を追加予定。

## 予定タスク (MVP)
1. west.yml 追加 (公式 main + pmw3610 ドライバソース取り込み方針)
2. シールド最小ポート
3. ポインタ設定 dtsi (センサ + processors)
4. キーマップ最小レイヤ (BASE/MOUSE/SCROLL/SLOW)
5. 初回ビルド検証

詳しくは `spec.md` のギャップ分析セクション参照。

## 前提ツールインストール
west 未インストールのため初回ビルド失敗 (code 127)。以下で導入:

```bash
python3 -m pip install --user west
export PATH="$HOME/.local/bin:$PATH"  # 必要ならシェルに追加
```

## ビルド方法

### ローカルビルド
```bash
cd src/modern-zmk-config
west init -l .
west update
west zephyr-export

# 左手側ビルド
west build -s zmk/app -b nice_nano_v2 -- -DSHIELD=charybdis_left -DZMK_CONFIG=$(pwd)/config

# 右手側ビルド (clean後)
west build -s zmk/app -b nice_nano_v2 -p -- -DSHIELD=charybdis_right -DZMK_CONFIG=$(pwd)/config
```

生成ファイル: `build/zephyr/zmk.uf2`

### GitHub Actions 自動ビルド
リポジトリにpush後、Actions タブから自動生成された `.uf2` をダウンロード可能。

`build.yaml` で定義されたビルドターゲット:
- `nice_nano_v2` + `charybdis_left`
- `nice_nano_v2` + `charybdis_right`  
- `nice_nano_v2` + `settings_reset`

## バージョン固定
ZMK & PMW3610 driver revisions pinned:
```
zmk: 4ec69cb7e658590adf6354027aca789b364a70c5 (main @ 2025-10-30)
zmk-pmw3610-driver: 1d9c2c68ca76012e1b1e5f6ef02fa5eadc4ca399 (main @ 2025-10-30)
```
Pin理由: 再現性確保 (上流更新による API/レジスタ初期化差分防止)。

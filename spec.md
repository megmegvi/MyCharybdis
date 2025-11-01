# Project Spec (Charybdis ZMK Config)

## 技術スタック (Purpose: 利用技術の俯瞰とバージョン把握)
- ZMK Firmware (Zephyr RTOS ベース)
- Zephyr 3.x (west manifest により取得)
- nice!nano v2 (nRF52840)
- PMW3610 センサー (外部モジュール/ドライバ)
- ビルドツール: west, CMake
- スクリプト: bash build.sh

## ディレクトリ/ファイル一覧 (Purpose: 構成と役割の明確化)
- west.yml: 必要な ZMK Core と外部モジュールの取得定義
- build.yaml: CI 用ビルドマトリクス (left/right/settings_reset) + artifact 命名
- build.sh: ローカルビルドスクリプト (all で settings_reset も生成)
- config/boards/shields/charybdis/
  - charybdis.dtsi:  統合シールド (kscan + matrix-transform)
  - charybdis_pointer.dtsi: ポインタ処理チェーン(予定/または追加別ファイル)
  - charybdis-layouts.dtsi: 物理レイアウト定義
  - charybdis.keymap: レイヤ/コンボ/動作定義 (&mkp 除去済み)
  - charybdis_left.overlay / charybdis_right.overlay: 最小差分 (左右識別)
  - *.conf: レイヤや split side 設定
  - charybdis.zmk.yml: (将来拡張用メタ)
- spec.md: 本仕様書
- README.md: 利用者向け概要

## グローバルスコープ設定/ノード (Purpose: Devicetree とキーマップの中心要素)
- chosen.zmk,kscan -> &kscan0
- chosen.zmk,physical-layout -> &charybdis_layout (transform を layout 内に紐付け)
- node: kscan0 (zmk,kscan-gpio-matrix)
  - diode-direction=row2col
  - col-gpios / row-gpios: 物理行列
- node: default_transform (zmk,matrix-transform)
  - map: 5x12 -> 論理配置 (左右対称用リマップ)
- keymap/layers: layer_0_default, layer_1_fn, layer_2_wheel, layer_3_config

## ポインタ処理構成 (Purpose: 将来/別ファイルでの processor チェーン概要)
- センサー: PMW3610 (SPI)
- 典型チェーン: sensor -> (scaler) -> (axis mapper) -> (accel など) -> pointing device report

## ビルドターゲット (Purpose: 生成物の体系化)
- charybdis_left (peripheral, Studio 無効)
- charybdis_right (central, Studio + RPC)
- settings_reset (設定消去/再初期化用 UF2)

## 安全なマトリクス変更ガイド (Purpose: RC mismatch 再発防止)
1. 物理配線 col/row の並びは devicetree の col-gpios/row-gpios をハード配線順に維持
2. 論理レイアウト変更は default_transform.map の RC(r,c) 入替で実施
3. 単一キーが反応しない場合: 行/列順序のズレを疑い RC 座標と transform 並びを検証
4. 変更多発時は settings_reset UF2 を一度 flash し NVS 設定キャッシュをクリアする

## settings_reset UF2 利用タイミング (Purpose: キャッシュ/設定不整合回避)
- 以下の操作後に一度実行推奨:
  - 行列サイズや transform の大幅改編
  - ポインタセンサー構成 (processor ノード) の名称変更
  - Bluetooth 設定破損/接続異常時

## 既存ワーニング対応状況 (Purpose: クリーンビルド維持)
- deprecated label (kscan, layer) -> 除去完了
- vendor prefix (pixart 等) -> 必要なら upstream prefix file 追加検討 (未対応メモ)

## 今後の改善候補 (Purpose: Backlog 可視化)
- ロギングレベル プロファイル化 (dev/release)
- ポインタ processor dtsi 実装と調整
- Bluetooth ペアリング関連 UX の README 追記

## 変更履歴要約 (Purpose: リファクタ追跡)
- Overlay 統合 -> charybdis.dtsi
- RC(2,1) 不具合 -> row 順序修正で解消
- &mkp 廃止 -> 標準 MS_BTN1/2 に移行
- CI build matrix artifact 名称追加
- orphan branch config-main で軽量化 (config-only)


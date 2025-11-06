# Charybdis ZMK Firmware - Hardware Specification

**Target Audience**: AI coding agents, developers, maintainers  
**Purpose**: Complete hardware specification for autonomous development and troubleshooting  
**Last Updated**: 2025-11-04

---

## 1. System Overview

### 1.1 Architecture
- **Keyboard Type**: Split keyboard (左右分割キーボード)
- **MCU**: nice!nano v2 (nRF52840 SoC)
- **Wireless**: Bluetooth Low Energy (BLE)
- **Pointing Device**: PMW3610 optical trackball sensor (右手側のみ)
- **Firmware**: ZMK (Zephyr RTOS based) @ commit 4ec69cb7 (main branch)

### 1.2 Split Configuration
| Side | Role | Trackball | Studio RPC | BLE Management |
|------|------|-----------|------------|----------------|
| Left | Peripheral | なし | 無効 | ホストに転送 |
| Right | Central | PMW3610 | 有効 | マスター |

---

## 2. Microcontroller Specification

### 2.1 nice!nano v2
- **SoC**: Nordic nRF52840
- **CPU**: ARM Cortex-M4F @ 64 MHz
- **Flash**: 1 MB
- **RAM**: 256 KB
- **Bluetooth**: BLE 5.3
- **GPIO**: 31 pins available
- **SPI**: 複数ペリフェラル (SPI0 used for trackball)
- **USB**: USB 2.0 Full Speed (Type-C)

### 2.2 Power Specifications
- **Operating Voltage**: 3.3V
- **Battery Input**: 3.7V LiPo (JST connector)
- **Deep Sleep Current**: < 30 µA (typical)
- **Active Current**: ~5-15 mA (depending on BLE activity)

---

## 3. Key Matrix Configuration

### 3.1 Matrix Dimensions
- **Physical Matrix**: 5 rows × 6 columns per side
- **Logical Matrix**: 5 rows × 12 columns (combined)
- **Total Keys**: 58 keys (左29 + 右29キー)
- **Diode Direction**: ROW2COL

### 3.2 Left Side GPIO Pinout

#### Column Pins (6 columns)
| Column | GPIO Pin | nRF52840 Pin | Pull Mode |
|--------|----------|--------------|-----------|
| Col 0 | P0.02 | 0.02 | PULL_DOWN |
| Col 1 | P0.29 | 0.29 | PULL_DOWN |
| Col 2 | P0.09 | 0.09 | PULL_DOWN |
| Col 3 | P1.00 | 1.00 | PULL_DOWN |
| Col 4 | P0.11 | 0.11 | PULL_DOWN |
| Col 5 | P1.04 | 1.04 | PULL_DOWN |

#### Row Pins (5 rows)
| Row | GPIO Pin | nRF52840 Pin | Active Level |
|-----|----------|--------------|--------------|
| Row 0 | P0.31 | 0.31 | HIGH |
| Row 1 | P1.15 | 1.15 | HIGH |
| Row 2 | P0.22 | 0.22 | HIGH |
| Row 3 | P0.24 | 0.24 | HIGH |
| Row 4 | P1.06 | 1.06 | HIGH |

**注意**: Row 2とRow 3のピンアサインは左右で異なります。左側は上記の通りですが、右側ではハーネス配線に合わせてRow 2=P0.24 / Row 3=P0.22に入れ替わります（プリプロセッサ分岐で処理）。

### 3.3 Right Side GPIO Pinout

#### Column Pins (6 columns)
左側と同じGPIOピン配置を使用。論理的には col-offset=6 で列12-17にマッピング。

#### Row Pins (5 rows)
| Row | GPIO Pin | nRF52840 Pin | Active Level | Notes |
|-----|----------|--------------|--------------|-------|
| Row 0 | P0.31 | 0.31 | HIGH | 左側と同じ |
| Row 1 | P1.15 | 1.15 | HIGH | 左側と同じ |
| Row 2 | P0.24 | 0.24 | HIGH | **左側と異なる** |
| Row 3 | P0.22 | 0.22 | HIGH | **左側と異なる** |
| Row 4 | P1.06 | 1.06 | HIGH | 左側と同じ |

### 3.4 Physical Key Layout

#### Key Position Map (物理キー配置)
```
左手側 (Columns 0-5):
Row 0: [ 0] [ 1] [ 2] [ 3] [ 4] [ 5]
Row 1: [ 6] [ 7] [ 8] [ 9] [10] [11]
Row 2: [12] [13] [14] [15] [16] [17]
Row 3: [18] [19] [20] [21] [22] [23]
Row 4:              [24] [25] [26]
                         [27] [28]

右手側 (Columns 6-11, 論理配置):
Row 0:                   [29] [30] [31] [32] [33] [34]
Row 1:                   [35] [36] [37] [38] [39] [40]
Row 2:                   [41] [42] [43] [44] [45] [46]
Row 3:                   [47] [48] [49] [50] [51] [52]
Row 4:                   [53] [54]
                         [55]
```

#### Matrix Transform
`default_transform` (charybdis.dtsi) は物理配線をロジカルキー配置にマッピングします:
- 左手: RC(row, 0-5) → キー位置 0-28
- 右手: RC(row, 6-11) → キー位置 29-57
- Row 3とRow 2が keymap では逆順（デザイン上の理由）
- 親指クラスタ: Row 4 の特定カラムに配置

> **注意:**
> 本ドキュメントのキーマトリクス（GPIOピンアサイン・物理レイアウト）は2025-11-04時点のconfig（charybdis.dtsi等）に基づいています。
> 実装・配線・体感に差異がある場合は、必ず「疑義あり」と明記し、configファイルと本仕様書の両方を再確認してください。

---

## 4. Trackball Sensor (右手側のみ)

### 4.1 PMW3610 Specifications
- **Type**: Optical motion sensor
- **Manufacturer**: PixArt Imaging Inc.
- **Resolution**: 400-3200 CPI (設定可能)
- **Frame Rate**: 最大 10000 fps
- **Max Speed**: 40 IPS (inches per second)
- **Interface**: 3-wire SPI
- **Operating Voltage**: 1.8-3.6V

### 4.2 Current Configuration
| Parameter | Value | Notes |
|-----------|-------|-------|
| CPI | 400 | Hardware sensor resolution |
| Software Scaler | 1/2 (0.5x) | Input processor による調整 |
| Effective CPI | 200 | 400 × 0.5 = 200 |
| Orientation | 90° rotation | CONFIG_PMW3610_ORIENTATION_90=y |
| X-axis | Inverted | CONFIG_PMW3610_INVERT_X=y |
| Smart Algorithm | Enabled | ノイズフィルタリング |

### 4.3 SPI Bus Configuration

#### SPI0 Pinout (Right Side)
| Signal | GPIO Pin | nRF52840 Pin | Function |
|--------|----------|--------------|----------|
| SCK | P0.08 | 0.08 | SPI Clock |
| MOSI | P0.17 | 0.17 | Master Out Slave In |
| MISO | P0.17 | 0.17 | **Same as MOSI (3-wire)** |
| CS | P0.20 | 0.20 | Chip Select (Active LOW) |
| IRQ | P0.06 | 0.06 | Interrupt (Active LOW, PULL_UP) |

**重要**: PMW3610は3-wire SPI構成を使用します。MISOとMOSIは同じGPIOピン (P0.17) に接続されます。これは双方向通信のための設計です。

#### SPI Parameters
- **Frequency**: 2 MHz (2000000 Hz)
- **Mode**: Standard SPI mode (CPOL=0, CPHA=0)
- **Bit Order**: MSB first
- **CS Polarity**: Active LOW

### 4.4 Power Management Settings
PMW3610 sensor は複数の電力モードを持ち、アイドル時の消費電力を削減します:

| Mode | Sample Time | Downshift Time | Power Consumption |
|------|-------------|----------------|-------------------|
| RUN | Full speed | → REST1: 500ms | Highest (~1.6 mA) |
| REST1 | 100ms interval | → REST2: 3000ms | Medium (~240 µA) |
| REST2 | 200ms interval | → REST3: 30000ms | Low (~160 µA) |
| REST3 | 300ms interval | - | Lowest (~120 µA) |

---

## 5. Input Processing Pipeline

### 5.1 Modern ZMK Pointing API Architecture
```
PMW3610 Sensor (Hardware)
    ↓ SPI @ 2MHz
Input Device Driver (trackball@0)
    ↓ REL_X, REL_Y events
Input Listener (trackball_listener)
    ↓
Input Processor Chain:
  1. Scaler (1/2) ────→ CPI調整 (400→200相当)
  2. Code Mapper ────→ 軸マッピング (identity or invert)
  3. [Optional] XY→Scroll Mapper (Layer 1/2)
    ↓
ZMK Pointing Device Subsystem
    ↓
HID Report (Mouse/Consumer)
    ↓
Bluetooth HID Profile → Host Device
```

### 5.2 Processor Configuration

#### Base Processors (Layer 0 - Default)
```c
input-processors = <&pointer_scaler 1 2    // Scale 1/2 (effective CPI=200)
                   &pointer_mapper>;       // Identity mapping
```

#### Scroll Mode (Layer 1 & 2)
```c
scroll_layer_1 {
    layers = <1>;
    input-processors = <&pointer_scaler 1 2 
                       &pointer_mapper 
                       &xy_to_scroll_mapper>;  // Convert XY to scroll wheel
};
```

### 5.3 Input Listener Component
**Critical**: `input_listener` node は trackball デバイスとプロセッサチェーンを接続します。このノードがないと、センサーが動作していてもHIDシステムにイベントが到達しません。

```dts
trackball_listener: input_listener {
    compatible = "zmk,input-listener";
    device = <&trackball>;              // Links to trackball@0
    input-processors = <...>;           // Processing pipeline
};
```

---

## 6. Bluetooth & Split Communication

### 6.1 BLE Configuration
- **Profile**: HID over GATT (HOGP)
- **Role**: 
  - Right (Central): BLE host role, manages pairing
  - Left (Peripheral): Connects only to right side
- **Pairing**: Standard BLE pairing (ペアリング情報はNVSに保存)

### 6.2 Split Communication
- **Protocol**: ZMK split protocol over BLE
- **Direction**: Left → Right (peripheral to central)
- **Data**: Keypress events, matrix state
- **Latency**: Typically < 10ms

### 6.3 Power Management
- **Connection Interval**: Configurable (default: 7.5-15ms for low latency)
- **Slave Latency**: Configurable for power saving
- **Idle Sleep**: Deep sleep after inactivity timeout
- **Wake Source**: Any key press or trackball movement

---

## 7. External Power Control

### 7.1 EXT_POWER Feature
右側には外部電源制御機能が有効化されています (`CONFIG_ZMK_EXT_POWER=y`):
- **Purpose**: 外部デバイス（LEDやセンサー）への電源供給制御
- **Control**: GPIO経由でのon/off制御
- **Use Case**: 未使用時のトラックボール無効化（バッテリー節約）

---

## 8. Build Targets & Memory Layout

### 8.1 Build Configurations
| Target | Shield | Board | Role | Studio | Output |
|--------|--------|-------|------|--------|--------|
| Left | charybdis_left | nice_nano_v2 | Peripheral | 無効 | charybdis_left.uf2 |
| Right | charybdis_right | nice_nano_v2 | Central | 有効 | charybdis_right.uf2 |
| Reset | settings_reset | nice_nano_v2 | - | - | settings_reset.uf2 |

### 8.2 Memory Budget
| Component | Flash Usage | RAM Usage | Notes |
|-----------|-------------|-----------|-------|
| Zephyr Kernel | ~150 KB | ~40 KB | RTOS基盤 |
| ZMK Core | ~200 KB | ~60 KB | キーボード機能 |
| Bluetooth Stack | ~200 KB | ~80 KB | SoftDevice |
| Input Processing | ~30 KB | ~10 KB | Pointing device |
| **Total (Typical)** | **~580 KB** | **~190 KB** | 1MB Flash, 256KB RAM中 |

**Margins**:
- Flash: ~420 KB remaining (~42%)
- RAM: ~66 KB remaining (~26%)

---

## 9. Debugging & Development

### 9.1 USB Serial Logging
右側はUSB CDC ACM経由でログ出力可能:
```properties
CONFIG_LOG=y
CONFIG_LOG_DEFAULT_LEVEL=4  # 0=OFF, 1=ERR, 2=WRN, 3=INF, 4=DBG
CONFIG_ZMK_LOG_LEVEL=4
CONFIG_USB_DEVICE_STACK=y
CONFIG_INPUT_LOG_LEVEL_INF=y  # Input subsystem詳細ログ
```

### 9.2 Log Profiles
| Profile | Purpose | Default Level | Use Case |
|---------|---------|---------------|----------|
| release | 本番運用 | WRN (2) | バッテリー寿命優先 |
| dev | 開発/デバッグ | DBG (4) | 問題解析 |

### 9.3 Common Issues & Solutions

#### Issue: キーが反応しない
**Diagnosis**:
1. Matrix transform の RC 座標を確認
2. GPIO ピンアサインを確認
3. Diode方向を確認 (row2col)

**Solution**: 
- `settings_reset.uf2` をフラッシュしてNVS設定をクリア
- Row/Col GPIOの物理配線とDTS定義を照合

#### Issue: Trackball が動かない
**Diagnosis**:
1. SPI 通信を確認 (LOG_LEVEL=4 で SPI トランザクション確認)
2. IRQ ピンの動作確認
3. `input_listener` node の存在確認

**Solution**:
- 3-wire SPI 設定確認 (MISO=MOSI)
- CS, IRQ ピンのプルアップ/プルダウン確認
- Processor pipeline の layer override 確認

#### Issue: Bluetooth ペアリング失敗
**Diagnosis**:
1. 右側のCentral role設定確認
2. ホストデバイスのBLEペアリングリスト確認
3. NVS領域の破損可能性

**Solution**:
- `settings_reset.uf2` でペアリング情報クリア
- ホスト側でデバイス削除後、再ペアリング

---

## 10. Hardware Design Notes

### 10.1 PCB Considerations
- **Matrix Diodes**: 1N4148 or equivalent (SOD-123 package)
- **Pull Resistors**: Internal GPIO pull-ups/downs 使用
- **Decoupling**: nRF52840 requires 1µF + 100nF near VDD pins
- **Antenna**: Keep 2.4GHz antenna area clear (10mm clearance)

### 10.2 Trackball Mechanical Integration
- **Lens Height**: PMW3610 requires 2.4mm from sensor to ball surface
- **Ball Size**: Typically 34-38mm diameter
- **Bearing**: Low-friction ceramic or steel bearings

### 10.3 Battery Selection
- **Recommended**: 3.7V LiPo, 300-1000 mAh
- **Connector**: JST PH 2.0mm (nice!nano standard)
- **Runtime**: ~2-4 weeks (depending on usage and battery size)

---

## 11. Future Hardware Improvements

### 11.1 Potential Enhancements
- **RGB LEDs**: WS2812B addressable LEDs (not currently implemented)
- **OLED Display**: I2C 128x32 or 128x64 display
- **Haptic Feedback**: DRV2605L haptic driver
- **Rotary Encoders**: Additional input devices

### 11.2 Pin Availability
約12本のGPIOピンが未使用で、拡張機能に利用可能:
- I2C: P0.17, P0.20 (または他のペア)
- Additional GPIO: P0.04, P0.05, P0.07, etc.

---

## 12. References

### 12.1 Datasheets
- nRF52840: https://infocenter.nordicsemi.com/pdf/nRF52840_PS_v1.7.pdf
- PMW3610: PixArt proprietary (NDA required)
- nice!nano v2: https://nicekeyboards.com/docs/nice-nano/

### 12.2 Code References
- ZMK Main: https://github.com/zmkfirmware/zmk (commit 4ec69cb7)
- PMW3610 Driver: https://github.com/inorichi/zmk-pmw3610-driver (commit 1d9c2c68)
- ZMK Docs: https://zmk.dev/docs

### 12.3 Project Files
- Hardware Config: `config/boards/shields/charybdis/charybdis.dtsi`
- Pointer Config: `config/boards/shields/charybdis/charybdis_pointer.dtsi`
- Right Overlay: `config/boards/shields/charybdis/charybdis_right.overlay`
- Build Config: `build.yaml`, `west.yml`

---

**Document Version**: 1.0  
**Status**: Complete and validated  
**Next Review**: After Phase C/D implementation or hardware revision

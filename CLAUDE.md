# dengon_daikou_morse

スマホのライト点滅でモールス信号を送受信するFlutterアプリ。
同アプリ同士での通信を前提とした設計。

- **送信**: 日本語テキスト → 和文モールス符号変換 → 背面ライト点滅
- **受信**: カメラで光点滅を検知 → モールス符号デコード → 日本語テキスト
- **対象プラットフォーム**: iOS / Android

---

## Steering

### アーキテクチャ規約（Riverpod + MVVM）

| 層 | 責務 | 実装場所 |
|---|---|---|
| Model | データ・ビジネスロジック | `lib/core/morse/` |
| ViewModel | 状態保持・UIロジック | `*_view_model.dart`（`@riverpod` Notifier） |
| View | UI描画のみ | `*_screen.dart`（`ConsumerWidget`） |

- View はロジックを持たない。ViewModel のメソッドを呼ぶだけ
- ViewModel は `@riverpod` アノテーションで定義（`riverpod_annotation` 使用）
- `.g.dart` ファイルは生成コードのため編集しない

### ディレクトリ規約

```
lib/
  main.dart
  app.dart                          # MaterialApp・ルーティング
  core/
    morse/
      morse_table.dart              # 和文モールス変換表（Map）
      morse_encoder.dart            # Model: テキスト → シーケンス変換
      morse_decoder.dart            # Model: シーケンス → テキスト変換
    constants.dart                  # 定数（単位時間デフォルト値など）
  features/
    send/
      send_screen.dart              # View
      send_view_model.dart          # ViewModel
      send_view_model.g.dart        # 生成コード（編集不要）
    receive/
      receive_screen.dart           # View
      receive_view_model.dart       # ViewModel
      receive_view_model.g.dart     # 生成コード（編集不要）
  widgets/                          # 複数featureで共有するWidget
```

### 実装方針

- 受信機能より送信機能を先に完成させる
- 受信の閾値・タイミング調整は実機テストで行う
- 受信機能は「条件が良ければ動く」レベルの期待値で進める

---

## Skills

### セットアップ

```bash
flutter pub get
make gen
```

### 開発

```bash
make ios         # iOSシミュレータ/実機で実行
make android     # Androidエミュレータ/実機で実行
make watch       # コード生成ウォッチ（開発中は常時起動推奨）
```

### ビルド

```bash
make build-ios      # IPAビルド
make build-android  # APKビルド
```

### その他

```bash
make clean       # flutter clean + pub get
flutter analyze  # 静的解析
flutter test     # テスト実行
```

### 権限設定

**Android** — `android/app/src/main/AndroidManifest.xml` の `<manifest>` 直下に追加:

```xml
<uses-permission android:name="android.permission.FLASHLIGHT"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

**iOS** — `ios/Runner/Info.plist` の `<dict>` 内に追加:

```xml
<key>NSCameraUsageDescription</key>
<string>モールス信号の受信にカメラを使用します</string>
```

---

## ドメイン知識

### 使用パッケージ

| パッケージ | 用途 | 種別 |
|---|---|---|
| `flutter_riverpod` | 状態管理 | dependencies |
| `riverpod_annotation` | `@riverpod` アノテーション | dependencies |
| `torch_light` | 背面ライトON/OFF制御 | dependencies |
| `camera` | カメラフレームストリーム取得 | dependencies |
| `wakelock_plus` | 送受信中のスリープ防止 | dependencies |
| `image_picker` | 送信画像の選択（フォルダ/カメラ） | dependencies |
| `image` | 画像の縮小・階調変換 | dependencies |
| `riverpod_generator` | コード生成 | dev_dependencies |
| `build_runner` | コード生成実行 | dev_dependencies |

### モールス点滅タイミング

単位時間 `unitMs`（デフォルト200ms、スライダーで50〜500ms調整可）を基準:

| 要素 | 長さ |
|---|---|
| ・（点） | 1単位 ON |
| ー（線） | 3単位 ON |
| 文字内の記号間 | 1単位 OFF |
| 文字間 | 3単位 OFF |
| 単語間 | 7単位 OFF |

### 通信プロトコル（同アプリ間）

送信は以下の順で点滅する。定義は `lib/core/morse/morse_protocol.dart`、受信側は `MorseDecoder` の状態機械（`ReceivePhase`）で位置ごとに解釈する:

1. **プリアンブル** `........`（点8連打）— 受信側の閾値安定と単位時間の自動校正用
2. **ヘッダー符号** — 和文: ホレ `-..---` / 欧文: CT `-.-.-` / 画像: BT `-...-`
3. **本文**（テキスト or 画像ビット列）
4. **終了符号**（テキストのみ）— 和文: ラタ `...-.` / 欧文: AR `.-.-.`

- 受信側の単位時間はプリアンブルの点の長さ（中央値）から自動検出するため、速度スライダーは送信側のみ
- ヘッダー・終了符号は文字表と衝突するものがある（CT=サ、AR=ン）ため、必ず状態機械の位置で解釈する
- 逆引き表は言語別（`kJapaneseMorseTableReverse` / `kEnglishMorseTableReverse`）。言語符号で確定してから選ぶ

### 画像送信（`morse_image_codec.dart` / `gray_image.dart`）

- 画像は縮小 + Floyd–Steinberg ディザで**2bit=4階調グレースケール化**（画質 = 長辺画素数: 低24 / 中32 / 高48）
- ビット列 = メタ17bit（幅8 + 高さ8 + 反転フラグ1）+ 画素×2bit（左上から行順、レベル0=黒〜3=白、MSB先行）
- ビットの点滅は 0=点（1単位ON）/ 1=線（3単位ON）、ビット間1単位OFF。OFF の長さは区切りに使わない
- 線は点の2倍の時間がかかるため、1が過半のビット列は全ビット反転して送信（レベル→3-レベルと等価。反転フラグで受信側が復元）
- 終了符号はなく、受信側は幅×高さの画素数に達した時点で完了 → カメラ自動停止
- 受信側は画素が届くたびに左上から逐次描画（`GrayImageView`、未受信部分はブルーグレー）

### 受信の制約

- カメラ30fps = フレームあたり約33msの検出限界 → 単位時間200ms以上推奨
- 自動露出（AE）が干渉するため露出ロックの検討が必要
- 動作条件の目安: 暗め〜普通の室内、距離1〜2m程度

---

## 実装進捗

- [x] pubspec.yaml にパッケージ追加
- [x] Android / iOS 権限設定
- [x] 和文モールス変換表（`morse_table.dart`）
- [x] モールスエンコーダー（`morse_encoder.dart`）
- [x] 送信ViewModel / 送信UI
- [x] モールスデコーダー（`morse_decoder.dart`）
- [x] 受信ViewModel / 受信UI
- [x] 通信プロトコル（開始合図・言語符号・終了符号・単位時間の自動校正）
- [x] 画像送受信（4階調ディザ変換・画質選択・想定送信時間・逐次表示）
- [ ] 実機2台での送受信テスト（閾値・ROI調整）

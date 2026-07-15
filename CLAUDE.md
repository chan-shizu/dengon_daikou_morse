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
  theme/
    app_theme.dart                  # 無線機風テーマ（GadgetColors / GadgetTextStyles / ThemeData）
  widgets/                          # 複数featureで共有するWidget
    gadget/                         # 無線機風の共通部品（Panel / LcdDisplay / Led / Button）
```

### デザイン規約（ポップ・ステッカー風）

- アプリアイコンと同配色のシアン背景 + 白カード + イエローアクセント（`GadgetColors.accent`）で統一。色は直接指定せず `GadgetColors` を使う
- カード・ボタンは太い暗色アウトライン（`GadgetColors.ink`）とオフセット影（ぼかしなし `Offset(0, 4)`）でステッカー風に浮かせる。角丸は大きめ（カード18 / ボタン16 / ディスプレイ14）
- ディスプレイ表示の英数字・記号・モールス符号は DSEG14 フォント（`GadgetTextStyles.lcd`）、日本語は NotoSansJP（`.lcdJa`）。地色は暗いティール + イエロー発光
- セクションは `GadgetPanel`（英字ラベル付き）、表示エリアは `LcdDisplay`、主操作は `GadgetButton`、状態は `LedIndicator`
- ゴールデンテストで DSEG を描画するには `flutter_test_config.dart` でのフォントロードが必要（設定済み）

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
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

**iOS** — `ios/Runner/Info.plist` の `<dict>` 内に追加:

```xml
<key>NSCameraUsageDescription</key>
<string>モールス信号の受信と送信画像の撮影にカメラを使用します</string>
<key>NSMicrophoneUsageDescription</key>
<string>音（トーン）によるモールス信号の受信にマイクを使用します</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>送信する画像の選択に写真ライブラリを使用します</string>
```

### リリース（iOSのみ・Codemagic）

- Bundle ID: `com.chanshizu.dengonDaikouMorse` / 表示名: 伝言代行モールス / Android はリリースしない
- CI定義は `codemagic.yaml`（`ios-release` ワークフロー）。ビルド成功で TestFlight まで自動アップロード、App Store 審査提出は手動
- Codemagic 側の前提: Team settings > Integrations > Developer Portal に App Store Connect API キーを **`codemagic`** という名前で登録（署名証明書・プロファイルはこのキーで取得・作成）
- Codemagic 側の前提2: App settings > Environment variables に環境変数グループ **`signing`** を作り、**`CERTIFICATE_PRIVATE_KEY`**（RSA 2048 秘密鍵、Secret 扱い）を登録。`ios_signing` の自動署名は "No matching profiles found" で失敗するため、CLI（`app-store-connect fetch-signing-files --create`）で明示的に署名取得している
- Apple 側の前提: App Store Connect に上記 Bundle ID でアプリを登録
- ビルド番号は Codemagic の `$BUILD_NUMBER` で自動採番。バージョン（`x.y.z`）は `pubspec.yaml` の `version:` を手動更新
- CI ではゴールデンテストを実行しない（環境のフォントレンダリング差で壊れるため。ロジックテストのみ）
- アプリアイコンは `dart run tool/generate_app_icon.dart` で全サイズ再生成できる（素材: `tool/app_icon_source.png`）

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
| `record` | マイクPCMストリーム取得（音受信） | dependencies |
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

### 伝送路（光 / 音）

プロトコルは共通で、ON/OFF の物理層だけが異なる。送信計画は `signal_plan.dart` の `SignalPulse` 列に統一。

| | 光 | 音 |
|---|---|---|
| 送信 | 背面ライト点滅（`torch_light`） | 3kHzトーンをWAVに合成し一括再生（`tone_synth.dart`。resume/pause はジッタが出るため不可） |
| 受信 | カメラ中央領域の輝度（30fps） | マイクPCM16 → Goertzel でトーン振幅（`goertzel.dart`、5ms窓） |
| 単位時間 | 50〜500ms（推奨200ms以上） | 10〜100ms（デフォルト20ms） |

- Goertzel の出力は輝度と同じ0〜255スケールにし、`LightSignalDetector` 以降を完全に共用する
- 音受信のタイムスタンプは累積サンプル数から算出（マイク取り込みジッタの影響なし）
- 送信モードの「光+音」は光のタイミングで音も鳴らす人間向け機能で、高速化とは別物

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
- [x] 音（トーン）での送受信（波形合成送信・Goertzelマイク受信・光/音選択）
- [ ] 実機2台での送受信テスト（閾値・ROI調整、音は環境ノイズ・残響の影響確認）
- [x] iOSリリース準備（Bundle ID・表示名・アイコン・codemagic.yaml）
- [ ] iOSリリース（Codemagic側のAPIキー登録 → TestFlight配信 → App Store審査提出）

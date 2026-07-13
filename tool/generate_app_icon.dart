// iOSアプリアイコン生成スクリプト。
// tool/app_icon_source.png（正方形PNG）を全サイズにリサイズして出力する。
//
// 実行: dart run tool/generate_app_icon.dart

import 'dart:io';

import 'package:image/image.dart' as img;

const _sourcePath = 'tool/app_icon_source.png';

// 出力ファイル名 → ピクセルサイズ（Contents.json の構成に対応）
const _outputs = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

void main() {
  final source = img.decodePng(File(_sourcePath).readAsBytesSync());
  if (source == null) {
    stderr.writeln('failed to decode $_sourcePath');
    exit(1);
  }
  if (source.width != source.height) {
    stderr.writeln('source image must be square '
        '(got ${source.width}x${source.height})');
    exit(1);
  }

  // App Store はアルファチャンネル付き1024アイコンを受け付けないためRGBに変換
  final opaque = source.convert(numChannels: 3);

  final outDir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
  for (final entry in _outputs.entries) {
    final resized = entry.value == opaque.width
        ? opaque
        : img.copyResize(
            opaque,
            width: entry.value,
            height: entry.value,
            interpolation: img.Interpolation.cubic,
          );
    File('${outDir.path}/${entry.key}')
        .writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('wrote ${entry.key} (${entry.value}px)');
  }
}

// モールス点滅の単位時間（ms）。受信側はプリアンブルから自動校正する。
const int kDefaultUnitMs = 200;
const int kMinUnitMs = 50;
const int kMaxUnitMs = 500;

// 音（トーン）送信。マイクは44.1kHzでサンプリングできるため、
// カメラ30fpsの光より大幅に短い単位時間で送れる
const double kToneHz = 3000;
const int kSoundDefaultUnitMs = 20;
const int kSoundMinUnitMs = 10;
const int kSoundMaxUnitMs = 100;

// 受信マイクのサンプリング設定
const int kAudioSampleRate = 44100;

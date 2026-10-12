import 'dart:io';
import 'dart:math' as math;

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Plays the caller-side ringback tone while an outgoing call is waiting.
/// The file is generated locally so no network or bundled media asset is
/// required, and it is deleted when the player is disposed.
class RingbackTone {
  final AudioPlayer _player = AudioPlayer();
  File? _file;

  Future<void> start() async {
    if (_player.playing) return;
    try {
      final directory = await getTemporaryDirectory();
      _file ??= File('${directory.path}/griot_ringback.wav');
      if (!await _file!.exists()) {
        await _file!.writeAsBytes(_waveBytes());
      }
      await _player.setFilePath(_file!.path);
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (_) {
      // Ringback is optional. A missing native audio/path-provider plugin
      // must never prevent the call from connecting or being cleaned up.
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    final file = _file;
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  List<int> _waveBytes() {
    const sampleRate = 44100;
    const channels = 1;
    const bitsPerSample = 16;
    // Familiar phone ringback cadence: two short rings, then a pause.
    const durationSeconds = 3.0;
    final samples = (sampleRate * durationSeconds).round();
    final dataLength = samples * channels * bitsPerSample ~/ 8;
    final bytes = <int>[];
    void putAscii(String value) => bytes.addAll(value.codeUnits);
    void put32(int value) => bytes.addAll([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
    void put16(int value) => bytes.addAll([value & 0xff, (value >> 8) & 0xff]);
    putAscii('RIFF');
    put32(36 + dataLength);
    putAscii('WAVEfmt ');
    put32(16);
    put16(1);
    put16(channels);
    put32(sampleRate);
    put32(sampleRate * channels * bitsPerSample ~/ 8);
    put16(channels * bitsPerSample ~/ 8);
    put16(bitsPerSample);
    putAscii('data');
    put32(dataLength);
    for (var i = 0; i < samples; i++) {
      final t = i / sampleRate;
      final cycle = t % durationSeconds;
      final inBurst = cycle < 0.42 || (cycle >= 0.62 && cycle < 1.04);
      const frequency = 425.0;
      final burstPosition = cycle < 0.42
          ? cycle
          : cycle >= 0.62 && cycle < 1.04
          ? cycle - 0.62
          : 0.0;
      final fade = inBurst
          ? math.min(
              1.0,
              math.min(burstPosition / 0.04, (0.42 - burstPosition) / 0.04),
            )
          : 0.0;
      final envelope = inBurst ? 0.10 * fade.clamp(0.0, 1.0) : 0.0;
      final sample = (math.sin(2 * math.pi * frequency * t) * envelope * 32767)
          .round();
      put16(sample < 0 ? sample + 65536 : sample);
    }
    return bytes;
  }
}

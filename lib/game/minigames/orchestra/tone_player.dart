import 'dart:typed_data';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

/// Generates and plays a continuous tone at a given frequency.
/// Uses a synthesized sine wave to create the tone dynamically.
class TonePlayer {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  
  /// Sample rate for audio synthesis
  static const int sampleRate = 44100;
  /// Duration of the generated audio buffer in seconds
  static const double bufferDuration = 2.0;
  
  TonePlayer();
  
  /// Start playing a tone at the specified frequency and volume.
  /// [frequency] in Hz (e.g., 440 for A4)
  /// [volume] from 0.0 to 1.0
  Future<void> startTone(double frequency, double volume) async {
    if (_isPlaying) {
      // Just update volume if already playing
      await _player.setVolume(volume.clamp(0.0, 1.0));
      return;
    }
    
    // Generate WAV data for the tone
    final wavBytes = _generateSineWave(frequency, bufferDuration);
    
    // Play from bytes
    await _player.setVolume(volume.clamp(0.0, 1.0));
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(BytesSource(wavBytes));
    _isPlaying = true;
  }
  
  /// Update volume while playing
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }
  
  /// Stop the currently playing tone
  Future<void> stopTone() async {
    if (_isPlaying) {
      await _player.stop();
      _isPlaying = false;
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await _player.dispose();
  }
  
  /// Generate a WAV file with a sine wave at the given frequency
  Uint8List _generateSineWave(double frequency, double duration) {
    final numSamples = (sampleRate * duration).toInt();
    final samples = Int16List(numSamples);
    
    // Generate sine wave samples
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Apply fade in/out at ends to avoid clicks
      double amplitude = 0.8;
      const fadeLength = 0.01; // 10ms fade
      if (t < fadeLength) {
        amplitude *= t / fadeLength;
      } else if (t > duration - fadeLength) {
        amplitude *= (duration - t) / fadeLength;
      }
      
      samples[i] = (sin(2 * pi * frequency * t) * amplitude * 32767).toInt();
    }
    
    // Build WAV file
    return _buildWav(samples);
  }
  
  /// Build a minimal WAV file from 16-bit PCM samples
  Uint8List _buildWav(Int16List samples) {
    final dataSize = samples.length * 2; // 16-bit = 2 bytes
    final fileSize = 44 + dataSize;
    
    final buffer = ByteData(fileSize);
    int offset = 0;
    
    // RIFF header
    buffer.setUint32(offset, 0x52494646, Endian.big); offset += 4; // "RIFF"
    buffer.setUint32(offset, fileSize - 8, Endian.little); offset += 4;
    buffer.setUint32(offset, 0x57415645, Endian.big); offset += 4; // "WAVE"
    
    // fmt chunk
    buffer.setUint32(offset, 0x666d7420, Endian.big); offset += 4; // "fmt "
    buffer.setUint32(offset, 16, Endian.little); offset += 4; // chunk size
    buffer.setUint16(offset, 1, Endian.little); offset += 2; // PCM
    buffer.setUint16(offset, 1, Endian.little); offset += 2; // mono
    buffer.setUint32(offset, sampleRate, Endian.little); offset += 4;
    buffer.setUint32(offset, sampleRate * 2, Endian.little); offset += 4; // byte rate
    buffer.setUint16(offset, 2, Endian.little); offset += 2; // block align
    buffer.setUint16(offset, 16, Endian.little); offset += 2; // bits per sample
    
    // data chunk
    buffer.setUint32(offset, 0x64617461, Endian.big); offset += 4; // "data"
    buffer.setUint32(offset, dataSize, Endian.little); offset += 4;
    
    // Write samples
    for (final sample in samples) {
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }
    
    return buffer.buffer.asUint8List();
  }
}

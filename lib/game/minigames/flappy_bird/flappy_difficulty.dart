/// Difficulty presets for Flappy Bob.
enum FlappyDifficulty { easy, medium, hard, extreme }

/// Tuning parameters for a given difficulty.
class FlappyDifficultyConfig {
  /// Pipe horizontal speed as a fraction of screen width per second.
  final double pipeSpeedFactor;

  /// Vertical gap between pipes as a fraction of screen height.
  final double pipeGap;

  /// Seconds between consecutive pipe spawns.
  final double spawnInterval;

  /// Multiplicative speed increase per pipe scored (e.g. 1.05 = +5%).
  final double speedRamp;

  /// Minimum milliseconds between flaps (debounce).
  final int flapCooldownMs;

  /// Maximum speed multiplier (caps horizontal speed).
  final double maxSpeedMultiplier;

  /// Maximum vertical deviation for the gap from the previous gap (as fraction of screen height).
  final double maxGapYDeviation;

  /// Silver coin reward multiplier.
  final double coinMultiplier;

  const FlappyDifficultyConfig({
    required this.pipeSpeedFactor,
    required this.pipeGap,
    required this.spawnInterval,
    required this.speedRamp,
    required this.maxSpeedMultiplier,
    required this.maxGapYDeviation,
    required this.flapCooldownMs,
    required this.coinMultiplier,
  });

  Duration get flapCooldown => Duration(milliseconds: flapCooldownMs);

  static const Map<FlappyDifficulty, FlappyDifficultyConfig> presets = {
    FlappyDifficulty.easy: FlappyDifficultyConfig(
      pipeSpeedFactor: 0.20,
      pipeGap: 0.32,
      spawnInterval: 3.5,
      speedRamp: 1.03,
      maxSpeedMultiplier: 1.8,
      maxGapYDeviation: 0.30,
      flapCooldownMs: 250,
      coinMultiplier: 1.0,
    ),
    FlappyDifficulty.medium: FlappyDifficultyConfig(
      pipeSpeedFactor: 0.28,
      pipeGap: 0.27,
      spawnInterval: 2.8,
      speedRamp: 1.05,
      maxSpeedMultiplier: 2.2,
      maxGapYDeviation: 0.28,
      flapCooldownMs: 200,
      coinMultiplier: 1.0,
    ),
    FlappyDifficulty.hard: FlappyDifficultyConfig(
      pipeSpeedFactor: 0.35,
      pipeGap: 0.23,
      spawnInterval: 2.2,
      speedRamp: 1.07,
      maxSpeedMultiplier: 2.5,
      maxGapYDeviation: 0.25,
      flapCooldownMs: 150,
      coinMultiplier: 2.0,
    ),
    FlappyDifficulty.extreme: FlappyDifficultyConfig(
      pipeSpeedFactor: 0.65,
      pipeGap: 0.18,
      spawnInterval: 1.3,
      speedRamp: 1.10,
      maxSpeedMultiplier: 3.0,
      maxGapYDeviation: 0.22,
      flapCooldownMs: 100,
      coinMultiplier: 4.0,
    ),
  };
}

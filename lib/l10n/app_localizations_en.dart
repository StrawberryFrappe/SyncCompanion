// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get statusSynced => 'SYNCED';

  @override
  String get statusConnected => 'CONNECTED';

  @override
  String get statusWaiting => 'WAITING';

  @override
  String get statusSearching => 'SEARCHING';

  @override
  String get statusLoading => 'LOADING';

  @override
  String get settingsTitle => 'SETTINGS';

  @override
  String get advancedSettings => 'ADVANCED SETTINGS';

  @override
  String get scanForDevices => 'SCAN FOR DEVICES';

  @override
  String get disconnectAndForget => 'DISCONNECT & FORGET';

  @override
  String get language => 'LANGUAGE';

  @override
  String get dailyMissions => 'Daily Missions';

  @override
  String get missionCompleted => 'Mission Completed!';

  @override
  String get noMissionsAvailable => 'No missions available today.';

  @override
  String goldReward(int amount) {
    return '+$amount Gold';
  }

  @override
  String get missionSyncMasterTitle => 'Sync Master';

  @override
  String missionSyncMasterDesc(int minutes) {
    return 'Stay synced for $minutes minutes today.';
  }

  @override
  String get missionGameTimeTitle => 'Game Time';

  @override
  String missionGameTimeDesc(int count) {
    return 'Play any minigame $count time(s).';
  }

  @override
  String get missionYummyTimeTitle => 'Yummy Time';

  @override
  String missionYummyTimeDesc(int count) {
    return 'Feed your pet $count times.';
  }

  @override
  String get foodStore => 'FOOD STORE';

  @override
  String silverCurrency(int amount) {
    return '$amount Silver';
  }

  @override
  String get buyButton => 'Buy';

  @override
  String get foodApple => 'Apple';

  @override
  String get foodBurger => 'Burger';

  @override
  String get foodSushi => 'Sushi';

  @override
  String get foodCake => 'Cake';

  @override
  String get foodWater => 'Water';

  @override
  String get games => 'GAMES';

  @override
  String get play => 'PLAY';

  @override
  String get gameFlappyBob => 'Flappy Bob';

  @override
  String get gameFlappyBobDesc => 'Shake or tap to fly!';

  @override
  String get gameOrchestra => 'Orchestra';

  @override
  String get gameOrchestraDesc => 'Make your pets sing!';

  @override
  String get gameDonut => 'donut.dart';

  @override
  String get gameDonutDesc => 'Zero gravity pastry';

  @override
  String get gameSbr => 'SBR';

  @override
  String get gameSbrDesc => 'Breakout with a twist';

  @override
  String get wardrobe => 'WARDROBE';

  @override
  String goldCurrency(int amount) {
    return '$amount GOLD';
  }

  @override
  String get equip => 'EQUIP';

  @override
  String get unequip => 'UNEQUIP';

  @override
  String get missingAsset => 'Missing';

  @override
  String costGold(int cost) {
    return '$cost G';
  }

  @override
  String get clothingFancyHat => 'Fancy Hat';

  @override
  String get clothingWinterEarmuffs => 'Winter Earmuffs';

  @override
  String get clothingFlowerCrown => 'Flower Crown';

  @override
  String get clothingCoolShades => 'Cool Shades';

  @override
  String get clothingLeafBeret => 'Leaf Beret';

  @override
  String get resetStats => 'RESET STATS';

  @override
  String get resetStatsTitle => 'Reset Stats';

  @override
  String get resetStatsConfirm =>
      'Are you sure you want to reset all pet stats? This cannot be undone.';

  @override
  String get cancel => 'CANCEL';

  @override
  String get save => 'SAVE';

  @override
  String get reset => 'RESET';

  @override
  String get confirm => 'CONFIRM';

  @override
  String get ok => 'OK';

  @override
  String get petStatsResetSuccess => 'Pet stats reset successfully';

  @override
  String get cloudConfiguration => 'Cloud Configuration';

  @override
  String get cloudConfigDesc =>
      'Configure the endpoint URL and device token for cloud sync.';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get deviceToken => 'Device Token';

  @override
  String get tokenScanned => 'Token Scanned! Remember to save.';

  @override
  String fullEndpoint(String url, String token) {
    return 'Full endpoint: $url/api/v1/$token/telemetry';
  }

  @override
  String get pulseOximeter => 'PULSE OXIMETER';

  @override
  String get temperatureSensor => 'TEMPERATURE SENSOR';

  @override
  String get rawDataTerminal => 'RAW DATA TERMINAL';

  @override
  String get rawDataTerminalTitle => 'Raw Data Terminal';

  @override
  String get statRates => 'STAT RATES';

  @override
  String get hungerDecay => 'Hunger Decay';

  @override
  String get happinessGainSynced => 'Happiness Gain (synced)';

  @override
  String get happinessDecayNotSynced => 'Happiness Decay (not synced)';

  @override
  String get notifications => 'NOTIFICATIONS';

  @override
  String get lowWellbeingAlertThreshold => 'Low Wellbeing Alert Threshold';

  @override
  String notifyWhenWellbeingDrops(String percent) {
    return 'Notify when wellbeing drops to $percent% or below';
  }

  @override
  String get cloudSync => 'CLOUD SYNC';

  @override
  String pending(int count) {
    return '$count pending';
  }

  @override
  String get baseUrlLabel => 'Base URL:';

  @override
  String get deviceTokenLabel => 'Device Token:';

  @override
  String get notSet => '(not set)';

  @override
  String get configure => 'CONFIGURE';

  @override
  String get flushQueue => 'FLUSH QUEUE';

  @override
  String get debugFakeSync => 'DEBUG: FAKE SYNC';

  @override
  String get overrideSyncStatus => 'Override Sync Status';

  @override
  String get synced => 'SYNCED';

  @override
  String get notSynced => 'NOT SYNCED';

  @override
  String get debugMissions => 'DEBUG: MISSIONS';

  @override
  String get resetDailyMissions => 'RESET DAILY MISSIONS';

  @override
  String get dailyMissionsReset => 'Daily missions reset!';

  @override
  String get forceRegenMissions =>
      'Force regenerate all daily missions (clears progress)';

  @override
  String get petStats => 'PET STATS';

  @override
  String get hunger => 'Hunger';

  @override
  String get happiness => 'Happiness';

  @override
  String get wellbeing => 'Wellbeing';

  @override
  String get economyDebug => 'ECONOMY (DEBUG)';

  @override
  String get addGold => '+100 GOLD';

  @override
  String get addSilver => '+100 SILVER';

  @override
  String get difficultyLabel => 'Difficulty';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get difficultyExtreme => 'Extreme';

  @override
  String get scanForDevicesTitle => 'Scan for Devices';

  @override
  String get disconnectForget => 'Disconnect & Forget';

  @override
  String get tokenDetected => 'Token Detected';

  @override
  String get isCorrectToken => 'Is this the correct token?';

  @override
  String cameraError(String code) {
    return 'Camera Error: $code';
  }

  @override
  String get alignQrCode => 'Align QR code within the frame';

  @override
  String get bluetoothDisabled => 'Bluetooth Disabled';

  @override
  String get bluetoothNeeded =>
      'Bluetooth needs to be enabled to scan for devices.';

  @override
  String get enableBluetooth => 'ENABLE BLUETOOTH';

  @override
  String get permissionsRequired => 'Permissions required';

  @override
  String get permissionsNeededBle =>
      'Bluetooth permissions are required. Please grant them in Settings or allow when prompted.';

  @override
  String get request => 'REQUEST';

  @override
  String get permissionsDenied =>
      'Could not acquire required permissions. Please grant them in Android Settings.';

  @override
  String get permissionsRequiredNative =>
      'Bluetooth permissions are required to run the native BLE service. Please grant them in Settings.';

  @override
  String get nativeServiceFailed => 'Native service failed';

  @override
  String get nativeServiceFailedDesc =>
      'Could not start the native BLE foreground service. Please ensure the app has the required permissions.';

  @override
  String get gameOver => 'GAME OVER';

  @override
  String scoreLabel(int score) {
    return 'Score: $score';
  }

  @override
  String silverReward(int coins) {
    return '+$coins Silver';
  }

  @override
  String get retry => 'RETRY';

  @override
  String get exit => 'EXIT';

  @override
  String get flappyBobTitle => 'FLAPPY BOB';

  @override
  String get shakeToFlap => 'Shake to flap!';

  @override
  String get tapToFlap => 'Tap to flap (No device)';

  @override
  String get foodSpriteHint => '(You get a food sprite!)';

  @override
  String get jumpSensitivity => 'Jump Sensitivity';

  @override
  String get high => 'High';

  @override
  String get low => 'Low';

  @override
  String get start => 'START';

  @override
  String get back => 'Back';

  @override
  String get petNeedsAttention => 'Your pet needs attention!';

  @override
  String get petWellbeingDropped =>
      'Your pet\'s wellbeing has dropped. Time to check on them!';

  @override
  String get deviceSynced => 'Your device is synced';

  @override
  String connectionStatusDevice(String deviceId) {
    return 'Device: $deviceId';
  }

  @override
  String get sbrTapToStart => 'Tap to Start!';

  @override
  String sbrCombo(int amount) {
    return 'Combo: $amount';
  }

  @override
  String sbrLevel(int level) {
    return 'Level: $level';
  }

  @override
  String sbrLives(int lives) {
    return 'Lives: $lives';
  }

  @override
  String get sbrCalibrationCenter => 'Hold arm straight and tap to confirm';

  @override
  String get sbrCalibrationLeft => 'Turn wrist max left and tap to confirm';

  @override
  String get sbrCalibrationRight => 'Turn wrist max right and tap to confirm';
}

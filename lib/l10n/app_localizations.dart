import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @statusSynced.
  ///
  /// In en, this message translates to:
  /// **'SYNCED'**
  String get statusSynced;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'CONNECTED'**
  String get statusConnected;

  /// No description provided for @statusWaiting.
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get statusWaiting;

  /// No description provided for @statusSearching.
  ///
  /// In en, this message translates to:
  /// **'SEARCHING'**
  String get statusSearching;

  /// No description provided for @statusLoading.
  ///
  /// In en, this message translates to:
  /// **'LOADING'**
  String get statusLoading;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsTitle;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'ADVANCED SETTINGS'**
  String get advancedSettings;

  /// No description provided for @scanForDevices.
  ///
  /// In en, this message translates to:
  /// **'SCAN FOR DEVICES'**
  String get scanForDevices;

  /// No description provided for @disconnectAndForget.
  ///
  /// In en, this message translates to:
  /// **'DISCONNECT & FORGET'**
  String get disconnectAndForget;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get language;

  /// No description provided for @dailyMissions.
  ///
  /// In en, this message translates to:
  /// **'Daily Missions'**
  String get dailyMissions;

  /// No description provided for @missionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mission Completed!'**
  String get missionCompleted;

  /// No description provided for @noMissionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No missions available today.'**
  String get noMissionsAvailable;

  /// No description provided for @goldReward.
  ///
  /// In en, this message translates to:
  /// **'+{amount} Gold'**
  String goldReward(int amount);

  /// No description provided for @missionSyncMasterTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Master'**
  String get missionSyncMasterTitle;

  /// No description provided for @missionSyncMasterDesc.
  ///
  /// In en, this message translates to:
  /// **'Stay synced for {minutes} minutes today.'**
  String missionSyncMasterDesc(int minutes);

  /// No description provided for @missionGameTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Game Time'**
  String get missionGameTimeTitle;

  /// No description provided for @missionGameTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Play any minigame {count} time(s).'**
  String missionGameTimeDesc(int count);

  /// No description provided for @missionYummyTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Yummy Time'**
  String get missionYummyTimeTitle;

  /// No description provided for @missionYummyTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Feed your pet {count} times.'**
  String missionYummyTimeDesc(int count);

  /// No description provided for @foodStore.
  ///
  /// In en, this message translates to:
  /// **'FOOD STORE'**
  String get foodStore;

  /// No description provided for @silverCurrency.
  ///
  /// In en, this message translates to:
  /// **'{amount} Silver'**
  String silverCurrency(int amount);

  /// No description provided for @buyButton.
  ///
  /// In en, this message translates to:
  /// **'Buy {cost} S'**
  String buyButton(int cost);

  /// No description provided for @foodApple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get foodApple;

  /// No description provided for @foodBurger.
  ///
  /// In en, this message translates to:
  /// **'Burger'**
  String get foodBurger;

  /// No description provided for @foodSushi.
  ///
  /// In en, this message translates to:
  /// **'Sushi'**
  String get foodSushi;

  /// No description provided for @foodCake.
  ///
  /// In en, this message translates to:
  /// **'Cake'**
  String get foodCake;

  /// No description provided for @foodWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get foodWater;

  /// No description provided for @games.
  ///
  /// In en, this message translates to:
  /// **'GAMES'**
  String get games;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'PLAY'**
  String get play;

  /// No description provided for @gameFlappyBob.
  ///
  /// In en, this message translates to:
  /// **'Flappy Bob'**
  String get gameFlappyBob;

  /// No description provided for @gameFlappyBobDesc.
  ///
  /// In en, this message translates to:
  /// **'Shake or tap to fly!'**
  String get gameFlappyBobDesc;

  /// No description provided for @gameOrchestra.
  ///
  /// In en, this message translates to:
  /// **'Orchestra'**
  String get gameOrchestra;

  /// No description provided for @gameOrchestraDesc.
  ///
  /// In en, this message translates to:
  /// **'Make your pets sing!'**
  String get gameOrchestraDesc;

  /// No description provided for @gameDonut.
  ///
  /// In en, this message translates to:
  /// **'donut.dart'**
  String get gameDonut;

  /// No description provided for @gameDonutDesc.
  ///
  /// In en, this message translates to:
  /// **'Zero gravity pastry'**
  String get gameDonutDesc;

  /// No description provided for @wardrobe.
  ///
  /// In en, this message translates to:
  /// **'WARDROBE'**
  String get wardrobe;

  /// No description provided for @goldCurrency.
  ///
  /// In en, this message translates to:
  /// **'{amount} GOLD'**
  String goldCurrency(int amount);

  /// No description provided for @equip.
  ///
  /// In en, this message translates to:
  /// **'EQUIP'**
  String get equip;

  /// No description provided for @unequip.
  ///
  /// In en, this message translates to:
  /// **'UNEQUIP'**
  String get unequip;

  /// No description provided for @missingAsset.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missingAsset;

  /// No description provided for @costGold.
  ///
  /// In en, this message translates to:
  /// **'{cost} G'**
  String costGold(int cost);

  /// No description provided for @clothingFancyHat.
  ///
  /// In en, this message translates to:
  /// **'Fancy Hat'**
  String get clothingFancyHat;

  /// No description provided for @clothingWinterEarmuffs.
  ///
  /// In en, this message translates to:
  /// **'Winter Earmuffs'**
  String get clothingWinterEarmuffs;

  /// No description provided for @clothingFlowerCrown.
  ///
  /// In en, this message translates to:
  /// **'Flower Crown'**
  String get clothingFlowerCrown;

  /// No description provided for @clothingCoolShades.
  ///
  /// In en, this message translates to:
  /// **'Cool Shades'**
  String get clothingCoolShades;

  /// No description provided for @clothingLeafBeret.
  ///
  /// In en, this message translates to:
  /// **'Leaf Beret'**
  String get clothingLeafBeret;

  /// No description provided for @resetStats.
  ///
  /// In en, this message translates to:
  /// **'RESET STATS'**
  String get resetStats;

  /// No description provided for @resetStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Stats'**
  String get resetStatsTitle;

  /// No description provided for @resetStatsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all pet stats? This cannot be undone.'**
  String get resetStatsConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get save;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get reset;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get confirm;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @petStatsResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Pet stats reset successfully'**
  String get petStatsResetSuccess;

  /// No description provided for @cloudConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Cloud Configuration'**
  String get cloudConfiguration;

  /// No description provided for @cloudConfigDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure the endpoint URL and device token for cloud sync.'**
  String get cloudConfigDesc;

  /// No description provided for @baseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrl;

  /// No description provided for @deviceToken.
  ///
  /// In en, this message translates to:
  /// **'Device Token'**
  String get deviceToken;

  /// No description provided for @tokenScanned.
  ///
  /// In en, this message translates to:
  /// **'Token Scanned! Remember to save.'**
  String get tokenScanned;

  /// No description provided for @fullEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Full endpoint: {url}/api/v1/{token}/telemetry'**
  String fullEndpoint(String url, String token);

  /// No description provided for @pulseOximeter.
  ///
  /// In en, this message translates to:
  /// **'PULSE OXIMETER'**
  String get pulseOximeter;

  /// No description provided for @temperatureSensor.
  ///
  /// In en, this message translates to:
  /// **'TEMPERATURE SENSOR'**
  String get temperatureSensor;

  /// No description provided for @rawDataTerminal.
  ///
  /// In en, this message translates to:
  /// **'RAW DATA TERMINAL'**
  String get rawDataTerminal;

  /// No description provided for @rawDataTerminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw Data Terminal'**
  String get rawDataTerminalTitle;

  /// No description provided for @statRates.
  ///
  /// In en, this message translates to:
  /// **'STAT RATES'**
  String get statRates;

  /// No description provided for @hungerDecay.
  ///
  /// In en, this message translates to:
  /// **'Hunger Decay'**
  String get hungerDecay;

  /// No description provided for @happinessGainSynced.
  ///
  /// In en, this message translates to:
  /// **'Happiness Gain (synced)'**
  String get happinessGainSynced;

  /// No description provided for @happinessDecayNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Happiness Decay (not synced)'**
  String get happinessDecayNotSynced;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get notifications;

  /// No description provided for @lowWellbeingAlertThreshold.
  ///
  /// In en, this message translates to:
  /// **'Low Wellbeing Alert Threshold'**
  String get lowWellbeingAlertThreshold;

  /// No description provided for @notifyWhenWellbeingDrops.
  ///
  /// In en, this message translates to:
  /// **'Notify when wellbeing drops to {percent}% or below'**
  String notifyWhenWellbeingDrops(String percent);

  /// No description provided for @cloudSync.
  ///
  /// In en, this message translates to:
  /// **'CLOUD SYNC'**
  String get cloudSync;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String pending(int count);

  /// No description provided for @baseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL:'**
  String get baseUrlLabel;

  /// No description provided for @deviceTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Device Token:'**
  String get deviceTokenLabel;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'(not set)'**
  String get notSet;

  /// No description provided for @configure.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURE'**
  String get configure;

  /// No description provided for @flushQueue.
  ///
  /// In en, this message translates to:
  /// **'FLUSH QUEUE'**
  String get flushQueue;

  /// No description provided for @debugFakeSync.
  ///
  /// In en, this message translates to:
  /// **'DEBUG: FAKE SYNC'**
  String get debugFakeSync;

  /// No description provided for @overrideSyncStatus.
  ///
  /// In en, this message translates to:
  /// **'Override Sync Status'**
  String get overrideSyncStatus;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'SYNCED'**
  String get synced;

  /// No description provided for @notSynced.
  ///
  /// In en, this message translates to:
  /// **'NOT SYNCED'**
  String get notSynced;

  /// No description provided for @debugMissions.
  ///
  /// In en, this message translates to:
  /// **'DEBUG: MISSIONS'**
  String get debugMissions;

  /// No description provided for @resetDailyMissions.
  ///
  /// In en, this message translates to:
  /// **'RESET DAILY MISSIONS'**
  String get resetDailyMissions;

  /// No description provided for @dailyMissionsReset.
  ///
  /// In en, this message translates to:
  /// **'Daily missions reset!'**
  String get dailyMissionsReset;

  /// No description provided for @forceRegenMissions.
  ///
  /// In en, this message translates to:
  /// **'Force regenerate all daily missions (clears progress)'**
  String get forceRegenMissions;

  /// No description provided for @petStats.
  ///
  /// In en, this message translates to:
  /// **'PET STATS'**
  String get petStats;

  /// No description provided for @hunger.
  ///
  /// In en, this message translates to:
  /// **'Hunger'**
  String get hunger;

  /// No description provided for @happiness.
  ///
  /// In en, this message translates to:
  /// **'Happiness'**
  String get happiness;

  /// No description provided for @wellbeing.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing'**
  String get wellbeing;

  /// No description provided for @economyDebug.
  ///
  /// In en, this message translates to:
  /// **'ECONOMY (DEBUG)'**
  String get economyDebug;

  /// No description provided for @addGold.
  ///
  /// In en, this message translates to:
  /// **'+100 GOLD'**
  String get addGold;

  /// No description provided for @addSilver.
  ///
  /// In en, this message translates to:
  /// **'+100 SILVER'**
  String get addSilver;

  /// No description provided for @difficultyLabel.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficultyLabel;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// No description provided for @difficultyExtreme.
  ///
  /// In en, this message translates to:
  /// **'Extreme'**
  String get difficultyExtreme;

  /// No description provided for @scanForDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan for Devices'**
  String get scanForDevicesTitle;

  /// No description provided for @disconnectForget.
  ///
  /// In en, this message translates to:
  /// **'Disconnect & Forget'**
  String get disconnectForget;

  /// No description provided for @tokenDetected.
  ///
  /// In en, this message translates to:
  /// **'Token Detected'**
  String get tokenDetected;

  /// No description provided for @isCorrectToken.
  ///
  /// In en, this message translates to:
  /// **'Is this the correct token?'**
  String get isCorrectToken;

  /// No description provided for @cameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera Error: {code}'**
  String cameraError(String code);

  /// No description provided for @alignQrCode.
  ///
  /// In en, this message translates to:
  /// **'Align QR code within the frame'**
  String get alignQrCode;

  /// No description provided for @bluetoothDisabled.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Disabled'**
  String get bluetoothDisabled;

  /// No description provided for @bluetoothNeeded.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth needs to be enabled to scan for devices.'**
  String get bluetoothNeeded;

  /// No description provided for @enableBluetooth.
  ///
  /// In en, this message translates to:
  /// **'ENABLE BLUETOOTH'**
  String get enableBluetooth;

  /// No description provided for @permissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Permissions required'**
  String get permissionsRequired;

  /// No description provided for @permissionsNeededBle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permissions are required. Please grant them in Settings or allow when prompted.'**
  String get permissionsNeededBle;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'REQUEST'**
  String get request;

  /// No description provided for @permissionsDenied.
  ///
  /// In en, this message translates to:
  /// **'Could not acquire required permissions. Please grant them in Android Settings.'**
  String get permissionsDenied;

  /// No description provided for @permissionsRequiredNative.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permissions are required to run the native BLE service. Please grant them in Settings.'**
  String get permissionsRequiredNative;

  /// No description provided for @nativeServiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Native service failed'**
  String get nativeServiceFailed;

  /// No description provided for @nativeServiceFailedDesc.
  ///
  /// In en, this message translates to:
  /// **'Could not start the native BLE foreground service. Please ensure the app has the required permissions.'**
  String get nativeServiceFailedDesc;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'GAME OVER'**
  String get gameOver;

  /// No description provided for @scoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String scoreLabel(int score);

  /// No description provided for @silverReward.
  ///
  /// In en, this message translates to:
  /// **'+{coins} Silver'**
  String silverReward(int coins);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get retry;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'EXIT'**
  String get exit;

  /// No description provided for @flappyBobTitle.
  ///
  /// In en, this message translates to:
  /// **'FLAPPY BOB'**
  String get flappyBobTitle;

  /// No description provided for @shakeToFlap.
  ///
  /// In en, this message translates to:
  /// **'Shake to flap!'**
  String get shakeToFlap;

  /// No description provided for @tapToFlap.
  ///
  /// In en, this message translates to:
  /// **'Tap to flap (No device)'**
  String get tapToFlap;

  /// No description provided for @foodSpriteHint.
  ///
  /// In en, this message translates to:
  /// **'(You get a food sprite!)'**
  String get foodSpriteHint;

  /// No description provided for @jumpSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Jump Sensitivity'**
  String get jumpSensitivity;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get start;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @petNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Your pet needs attention!'**
  String get petNeedsAttention;

  /// No description provided for @petWellbeingDropped.
  ///
  /// In en, this message translates to:
  /// **'Your pet\'s wellbeing has dropped. Time to check on them!'**
  String get petWellbeingDropped;

  /// No description provided for @deviceSynced.
  ///
  /// In en, this message translates to:
  /// **'Your device is synced'**
  String get deviceSynced;

  /// No description provided for @connectionStatusDevice.
  ///
  /// In en, this message translates to:
  /// **'Device: {deviceId}'**
  String connectionStatusDevice(String deviceId);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

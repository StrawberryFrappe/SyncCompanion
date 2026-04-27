// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get statusSynced => 'SINCRONIZADO';

  @override
  String get statusConnected => 'CONECTADO';

  @override
  String get statusWaiting => 'ESPERANDO';

  @override
  String get statusSearching => 'BUSCANDO';

  @override
  String get statusLoading => 'CARGANDO';

  @override
  String get settingsTitle => 'AJUSTES';

  @override
  String get advancedSettings => 'AJUSTES AVANZADOS';

  @override
  String get scanForDevices => 'BUSCAR DISPOSITIVOS';

  @override
  String get disconnectAndForget => 'DESCONECTAR Y OLVIDAR';

  @override
  String get language => 'IDIOMA';

  @override
  String get appVersion => 'Versión de la App';

  @override
  String get appUpdates => 'ACTUALIZACIONES DE LA APLICACIÓN';

  @override
  String get nightlyUpdates => 'Actualizaciones Nocturnas (Nightly)';

  @override
  String get nightlyUpdatesDesc =>
      'Detectar y actualizar automáticamente a compilaciones preliminares (dev).';

  @override
  String get dailyMissions => 'Misiones Diarias';

  @override
  String get missionCompleted => '¡Misión Completada!';

  @override
  String get noMissionsAvailable => 'No hay misiones disponibles hoy.';

  @override
  String goldReward(int amount) {
    return '+$amount Oro';
  }

  @override
  String get missionSyncMasterTitle => 'Maestro Sync';

  @override
  String missionSyncMasterDesc(int minutes) {
    return 'Mantente sincronizado por $minutes minutos hoy.';
  }

  @override
  String get missionGameTimeTitle => 'Hora de Jugar';

  @override
  String missionGameTimeDesc(int count) {
    return 'Juega cualquier minijuego $count vez/veces.';
  }

  @override
  String get missionYummyTimeTitle => 'Hora de Comer';

  @override
  String missionYummyTimeDesc(int count) {
    return 'Alimenta a tu mascota $count veces.';
  }

  @override
  String get foodStore => 'TIENDA DE COMIDA';

  @override
  String silverCurrency(int amount) {
    return '$amount Plata';
  }

  @override
  String get buyButton => 'Comprar';

  @override
  String get foodApple => 'Manzana';

  @override
  String get foodBurger => 'Hamburguesa';

  @override
  String get foodSushi => 'Sushi';

  @override
  String get foodCake => 'Pastel';

  @override
  String get foodWater => 'Agua';

  @override
  String get games => 'JUEGOS';

  @override
  String get play => 'JUGAR';

  @override
  String get gameFlappyBob => 'Flappy Bob';

  @override
  String get gameFlappyBobDesc => '¡Sacude o toca para volar!';

  @override
  String get gameOrchestra => 'Orquesta';

  @override
  String get gameOrchestraDesc => 'Make your pets sing!';

  @override
  String get gameDonut => 'donut.dart';

  @override
  String get gameDonutDesc => 'Pastelería sin gravedad';

  @override
  String get gameSbr => 'SBR';

  @override
  String get gameSbrDesc => 'Breakout con un giro';

  @override
  String get wardrobe => 'VESTUARIO';

  @override
  String goldCurrency(int amount) {
    return '$amount ORO';
  }

  @override
  String get equip => 'EQUIPAR';

  @override
  String get unequip => 'DESEQUIPAR';

  @override
  String get missingAsset => 'Faltante';

  @override
  String costGold(int cost) {
    return '$cost O';
  }

  @override
  String get clothingFancyHat => 'Sombrero Elegante';

  @override
  String get clothingWinterEarmuffs => 'Orejeras de Invierno';

  @override
  String get clothingFlowerCrown => 'Corona de Flores';

  @override
  String get clothingCoolShades => 'Lentes de Sol';

  @override
  String get clothingLeafBeret => 'Boina de Hojas';

  @override
  String get resetStats => 'REINICIAR STATS';

  @override
  String get resetStatsTitle => 'Reiniciar Stats';

  @override
  String get resetStatsConfirm =>
      '¿Estás seguro de que quieres reiniciar las estadísticas de tu mascota? Esto no se puede deshacer.';

  @override
  String get cancel => 'CANCELAR';

  @override
  String get save => 'GUARDAR';

  @override
  String get reset => 'REINICIAR';

  @override
  String get confirm => 'CONFIRMAR';

  @override
  String get ok => 'OK';

  @override
  String get petStatsResetSuccess => 'Estadísticas reiniciadas exitosamente';

  @override
  String get cloudConfiguration => 'Configuración de Nube';

  @override
  String get cloudConfigDesc =>
      'Configura la URL del servidor y el token del dispositivo para sincronización en la nube.';

  @override
  String get baseUrl => 'URL Base';

  @override
  String get deviceToken => 'Token del Dispositivo';

  @override
  String get tokenScanned => '¡Token escaneado! Recuerda guardar.';

  @override
  String fullEndpoint(String url, String token) {
    return 'Endpoint completo: $url/api/v1/$token/telemetry';
  }

  @override
  String get pulseOximeter => 'OXÍMETRO DE PULSO';

  @override
  String get temperatureSensor => 'SENSOR DE TEMPERATURA';

  @override
  String get rawDataTerminal => 'TERMINAL DE DATOS';

  @override
  String get rawDataTerminalTitle => 'Terminal de Datos';

  @override
  String get statRates => 'TASAS DE STATS';

  @override
  String get hungerDecay => 'Decaimiento de Hambre';

  @override
  String get happinessGainSynced => 'Ganancia de Felicidad (sincronizado)';

  @override
  String get happinessDecayNotSynced =>
      'Decaimiento de Felicidad (no sincronizado)';

  @override
  String get notifications => 'NOTIFICACIONES';

  @override
  String get lowWellbeingAlertThreshold => 'Umbral de Alerta de Bienestar Bajo';

  @override
  String notifyWhenWellbeingDrops(String percent) {
    return 'Notificar cuando el bienestar baje al $percent% o menos';
  }

  @override
  String get cloudSync => 'SINCRONIZACIÓN EN LA NUBE';

  @override
  String pending(int count) {
    return '$count pendientes';
  }

  @override
  String get baseUrlLabel => 'URL Base:';

  @override
  String get deviceTokenLabel => 'Token del Dispositivo:';

  @override
  String get notSet => '(no configurado)';

  @override
  String get configure => 'CONFIGURAR';

  @override
  String get flushQueue => 'ENVIAR COLA';

  @override
  String get debugFakeSync => 'DEBUG: SYNC FALSO';

  @override
  String get overrideSyncStatus => 'Anular Estado de Sync';

  @override
  String get synced => 'SINCRONIZADO';

  @override
  String get notSynced => 'NO SINCRONIZADO';

  @override
  String get debugMissions => 'DEBUG: MISIONES';

  @override
  String get resetDailyMissions => 'REINICIAR MISIONES DIARIAS';

  @override
  String get dailyMissionsReset => '¡Misiones diarias reiniciadas!';

  @override
  String get forceRegenMissions =>
      'Forzar regeneración de misiones diarias (borra progreso)';

  @override
  String get petStats => 'STATS DE MASCOTA';

  @override
  String get hunger => 'Hambre';

  @override
  String get happiness => 'Felicidad';

  @override
  String get wellbeing => 'Bienestar';

  @override
  String get economyDebug => 'ECONOMÍA (DEBUG)';

  @override
  String get addGold => '+100 ORO';

  @override
  String get addSilver => '+100 PLATA';

  @override
  String get difficultyLabel => 'Dificultad';

  @override
  String get difficultyEasy => 'Fácil';

  @override
  String get difficultyMedium => 'Medio';

  @override
  String get difficultyHard => 'Difícil';

  @override
  String get difficultyExtreme => 'Extremo';

  @override
  String get scanForDevicesTitle => 'Buscar Dispositivos';

  @override
  String get disconnectForget => 'Desconectar y Olvidar';

  @override
  String get tokenDetected => 'Token Detectado';

  @override
  String get isCorrectToken => '¿Es este el token correcto?';

  @override
  String cameraError(String code) {
    return 'Error de Cámara: $code';
  }

  @override
  String get alignQrCode => 'Alinea el código QR dentro del marco';

  @override
  String get bluetoothDisabled => 'Bluetooth Desactivado';

  @override
  String get bluetoothNeeded =>
      'Se necesita activar el Bluetooth para buscar dispositivos.';

  @override
  String get enableBluetooth => 'ACTIVAR BLUETOOTH';

  @override
  String get permissionsRequired => 'Permisos requeridos';

  @override
  String get permissionsNeededBle =>
      'Se requieren permisos de Bluetooth. Por favor concédelos en Ajustes o al recibir la solicitud.';

  @override
  String get request => 'SOLICITAR';

  @override
  String get permissionsDenied =>
      'No se pudieron obtener los permisos requeridos. Por favor concédelos en Ajustes de Android.';

  @override
  String get permissionsRequiredNative =>
      'Se requieren permisos de Bluetooth para ejecutar el servicio BLE nativo. Por favor concédelos en Ajustes.';

  @override
  String get nativeServiceFailed => 'Servicio nativo falló';

  @override
  String get nativeServiceFailedDesc =>
      'No se pudo iniciar el servicio BLE nativo. Por favor asegúrate de que la app tenga los permisos necesarios.';

  @override
  String get gameOver => 'FIN DEL JUEGO';

  @override
  String scoreLabel(int score) {
    return 'Puntaje: $score';
  }

  @override
  String silverReward(int coins) {
    return '+$coins Plata';
  }

  @override
  String get retry => 'REINTENTAR';

  @override
  String get exit => 'SALIR';

  @override
  String get flappyBobTitle => 'FLAPPY BOB';

  @override
  String get shakeToFlap => '¡Sacude para volar!';

  @override
  String get tapToFlap => 'Toca para volar (Sin dispositivo)';

  @override
  String get foodSpriteHint => '(¡Obtienes un sprite de comida!)';

  @override
  String get jumpSensitivity => 'Sensibilidad de Salto';

  @override
  String get high => 'Alta';

  @override
  String get low => 'Baja';

  @override
  String get start => 'INICIAR';

  @override
  String get back => 'Volver';

  @override
  String get petNeedsAttention => '¡Tu mascota necesita atención!';

  @override
  String get petWellbeingDropped =>
      'El bienestar de tu mascota ha bajado. ¡Es hora de revisarla!';

  @override
  String get deviceSynced => 'Tu dispositivo está sincronizado';

  @override
  String connectionStatusDevice(String deviceId) {
    return 'Dispositivo: $deviceId';
  }

  @override
  String get sbrTapToStart => '¡Toca para empezar!';

  @override
  String sbrCombo(int amount) {
    return 'Combo: $amount';
  }

  @override
  String sbrLevel(int level) {
    return 'Nivel: $level';
  }

  @override
  String sbrLives(int lives) {
    return 'Vidas: $lives';
  }

  @override
  String get sbrCalibrationCenter =>
      'Mantén el brazo recto y toca para confirmar';

  @override
  String get sbrCalibrationLeft =>
      'Gira la muñeca a la izquierda al máximo y toca para confirmar';

  @override
  String get sbrCalibrationRight =>
      'Gira la muñeca a la derecha al máximo y toca para confirmar';
}

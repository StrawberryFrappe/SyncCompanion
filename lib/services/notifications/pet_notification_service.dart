import 'package:flutter/services.dart';
import '../locale_service.dart';

/// Service for sending pet-related notifications to the user.
class PetNotificationService {
  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  final LocaleService _localeService;

  PetNotificationService({required LocaleService localeService}) : _localeService = localeService;

  /// Show a notification alerting the user that their pet's wellbeing is low.
  Future<void> showLowWellbeingNotification() async {
    try {
      final isSpanish = _localeService.locale.languageCode == 'es';
      await _platform.invokeMethod('showPetAlert', {
        'title': isSpanish ? '¡Tu mascota necesita atención!' : 'Your pet needs attention!',
        'message': isSpanish ? 'El bienestar de tu mascota ha bajado. ¡Es hora de revisarla!' : 'Your pet\'s wellbeing has dropped. Time to check on them!',
      });
    } catch (e) {
      print('[PetNotificationService] Failed to show notification: $e');
    }
  }
}

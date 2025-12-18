import 'package:flutter/services.dart';

/// Service for sending pet-related notifications to the user.
class PetNotificationService {
  static const MethodChannel _platform = MethodChannel('sync_companion/bluetooth');
  
  /// Singleton instance
  static final PetNotificationService _instance = PetNotificationService._();
  factory PetNotificationService() => _instance;
  PetNotificationService._();

  /// Show a notification alerting the user that their pet's wellbeing is low.
  Future<void> showLowWellbeingNotification() async {
    try {
      await _platform.invokeMethod('showPetAlert', {
        'title': 'Your pet needs attention!',
        'message': 'Your pet\'s wellbeing has dropped. Time to check on them!',
      });
    } catch (e) {
      print('[PetNotificationService] Failed to show notification: $e');
    }
  }
}

export 'push_exception.dart';

import 'push_exception.dart';

/// Repli non-web : le Web Push n'existe pas sur ces cibles.
class PushNotifications {
  const PushNotifications._();

  static bool get isSupported => false;

  static String get permission => 'unsupported';

  static Future<void> enable() async {
    throw const PushException(
      'Les notifications push ne sont disponibles que dans la version web.',
    );
  }

  static Future<void> disable() async {}

  static Future<bool> isActive() async => false;
}

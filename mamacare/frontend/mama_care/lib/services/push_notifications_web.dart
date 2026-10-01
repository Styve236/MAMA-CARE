export 'push_exception.dart';

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'api_client.dart';
import 'push_exception.dart';

@JS('mamaCarePush')
external JSObject? get _helper;

/// Forme du résultat renvoyé par `web/push_helper.js` :
/// `{ ok, error?, active?, removed? }`.
extension type _Result._(JSObject object) implements JSObject {
  external bool? get ok;
  external String? get error;
  external bool? get active;
}

/// Convertit la valeur renvoyée par le helper JS (une `Promise`) en
/// objet [_Result]. Les fonctions JS ne rejettent jamais : elles résolvent
/// toujours `{ ok: ... }`, donc aucune exception JS ne doit traverser ici.
Future<_Result> _await(JSAny? returned) async {
  final promise = returned.jsify() as JSPromise<JSAny?>?;
  if (promise == null) {
    throw const PushException('Réponse illisible du navigateur.');
  }
  final resolved = await promise.toDart;
  final object = resolved as JSObject?;
  if (object == null) {
    throw const PushException('Réponse vide du navigateur.');
  }
  return _Result._(object);
}

/// Notifications push Web (VAPID) — implémentation navigateur.
///
/// Le travail réel est fait par `web/push_helper.js` : le Dart ne fait que
/// piloter la permission et lire le résultat.
class PushNotifications {
  const PushNotifications._();

  static bool get isSupported {
    final helper = _helper;
    if (helper == null) return false;
    return (helper.callMethod('isSupported'.toJS) as JSBoolean?)?.toDart ??
        false;
  }

  static String get permission {
    final helper = _helper;
    if (helper == null) return 'unsupported';
    final value = helper.callMethod('permission'.toJS) as JSString?;
    return value?.toDart ?? 'unsupported';
  }

  /// Demande la permission puis enregistre l'abonnement de CE compte.
  /// Le backend rattache la souscription à l'utilisateur du JWT.
  static Future<void> enable() async {
    final helper = _helper;
    if (helper == null) {
      throw const PushException(
        'Notifications push non supportées par ce navigateur.',
      );
    }
    final result = await _await(
      helper.callMethod(
        'subscribe'.toJS,
        ApiClient.baseUrl.toJS,
        (ApiClient.authToken ?? '').toJS,
      ),
    );
    if (result.ok != true) {
      throw PushException(result.error ?? 'Activation impossible.');
    }
  }

  /// Supprime l'abonnement local et côté backend.
  static Future<void> disable() async {
    final helper = _helper;
    if (helper == null) return;
    final result = await _await(
      helper.callMethod(
        'unsubscribe'.toJS,
        ApiClient.baseUrl.toJS,
        (ApiClient.authToken ?? '').toJS,
      ),
    );
    if (result.ok != true) {
      throw PushException(result.error ?? 'Désactivation impossible.');
    }
  }

  /// `true` si ce navigateur possède déjà un abonnement pour cette origine.
  static Future<bool> isActive() async {
    final helper = _helper;
    if (helper == null) return false;
    final result = await _await(helper.callMethod('currentSubscription'.toJS));
    return result.ok == true && result.active == true;
  }
}
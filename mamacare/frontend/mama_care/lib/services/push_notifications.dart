// Notifications push Web : point d'entrée unique.
//
// L'implémentation réelle est chargée conditionnellement selon la cible
// (navigateur vs. mobile/bureau), afin que ce package reste analysable
// pour toutes les plateformes.
export 'push_notifications_stub.dart'
    if (dart.library.js_interop) 'push_notifications_web.dart';
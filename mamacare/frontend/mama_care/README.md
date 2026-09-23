# MamaCare

Application Flutter connectée au backend Dart, lui-même connecté à Supabase PostgreSQL.

## Démarrage local

Pour démarrer automatiquement le backend puis Flutter avec le même port,
utiliser le lanceur PowerShell depuis le dossier `mama_care` :

```powershell
.\start_app.ps1 -Device chrome -NoWebResourcesCdn
```

Le script choisit un port libre, attend que l'endpoint `/health` réponde, passe
la valeur correcte de `API_BASE_URL` à Flutter, puis arrête le backend lorsque
Flutter se termine. Pour l'émulateur Android :

```powershell
.\start_app.ps1 -Device emulator-5554
```

La commande `flutter run` seule ne peut pas lancer un processus backend séparé
sur toutes les cibles Flutter (Web, Android et iOS). La tâche VS Code
`MamaCare: lancer application complète` utilise donc ce lanceur tout-en-un.

Dans un terminal, démarrer l’API :

```text
cd frontend/mama_care/backend
dart pub get
dart run bin/server.dart
```

Depuis le dossier `mama_care`, le script équivalent est :

```powershell
.\start_backend.ps1
```

Le dossier `server/` est obsolète et ne contient pas le serveur. Utiliser
uniquement `backend/`.

Puis lancer Flutter avec l’URL correspondant à la cible :

```text
# Windows, web ou iOS simulator
flutter run --dart-define=API_BASE_URL=http://localhost:3000

# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Si Chrome ne peut pas accéder à `gstatic.com`, utiliser les ressources Flutter
Web locales :

```text
flutter run -d chrome --no-web-resources-cdn
flutter build web --no-web-resources-cdn
```

Le schéma SQL à exécuter dans Supabase est `backend/schema.sql`. Le fichier `backend/.env`
reste local et ne doit jamais être intégré au code Flutter.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# MamaCare Dart Backend

This is a Dart-based backend for MamaCare, implemented with shelf and PostgreSQL. It mirrors the functionality of the existing Node/Express backend so Flutter developers can work in a single language.

Prerequisites
- Dart SDK (>=2.18)
- PostgreSQL

Setup
1. cd frontend/mama_care/backend
2. dart pub get
3. Create a `.env` from `.env.example` and fill in the Supabase database password.
4. Apply the migrations with `dart run bin/migrate.dart`.
5. Run the server:
   dart run bin/server.dart

To create or update the database, run the migrations from the same directory:

```text
dart run bin/migrate.dart
```

Applied migrations are tracked in the `schema_migrations` table and are skipped
when run again. The current migrations create the core MamaCare tables plus the
`statistics` and `admin_actions` tables used by the admin module.

The server connects to Supabase PostgreSQL through the transaction pooler. Never put
`DB_PASSWORD` in Flutter code or commit the `.env` file.

Environment variables:
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- `JWT_SECRET`, `PORT` (port préféré; si le port est occupé, le serveur essaie
   automatiquement les 99 ports suivants)

Au démarrage, l'URL avec le port effectivement choisi est affichée. Si le
serveur doit utiliser un port différent de `3000`, lancez Flutter avec cette
URL, par exemple `flutter run --dart-define=API_BASE_URL=http://localhost:3001`.

Notes
- Uses packages: shelf, shelf_router, postgres, dotenv, dart_jsonwebtoken, bcrypt
- Implemented endpoints: /health, /api/auth/(register,login,verify), /api/patient/*, /api/doctor/*, /api/admin/*

This is a starting implementation — expand controllers/services as needed.

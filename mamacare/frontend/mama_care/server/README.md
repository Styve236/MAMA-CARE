# MamaCare Dart Backend

This is a Dart-based backend for MamaCare, implemented with shelf and PostgreSQL. It mirrors the functionality of the existing Node/Express backend so Flutter developers can work in a single language.

Prerequisites
- Dart SDK (>=2.18)
- PostgreSQL

Setup
1. cd frontend/mama_care/backend
2. dart pub get
3. Create a `.env` from `.env.example` and fill in the Supabase database password.
4. Apply `schema.sql` to the Supabase SQL editor if the tables do not exist.
5. Run the server:
   dart run bin/server.dart

To create or update the database, run the migrations from the same directory:

```text
dart run bin/migrate.dart
```

Applied migrations are tracked in the `schema_migrations` table and are skipped
when run again.

The server connects to Supabase PostgreSQL through the transaction pooler. Never put
`DB_PASSWORD` in Flutter code or commit the `.env` file.

Environment variables:
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- `JWT_SECRET`, `PORT`

Notes
- Uses packages: shelf, shelf_router, postgres, dotenv, dart_jsonwebtoken, bcrypt
- Implemented endpoints: /health, /api/auth/(register,login,verify), /api/patient/*, /api/doctor/*, /api/admin/*

This is a starting implementation — expand controllers/services as needed.

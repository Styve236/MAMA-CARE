# MamaCare Dart Backend

This is a Dart-based backend for MamaCare, implemented with shelf and PostgreSQL. It mirrors the functionality of the existing Node/Express backend so Flutter developers can work in a single language.

Prerequisites
- Dart SDK (>=2.18)
- PostgreSQL

Setup
1. cd backend
2. dart pub get
3. copy the SQL schema into your database or run the schema file:
   psql -U <user> -d mamacare_db -f lib/models/schema.sql
4. Create a .env in backend with the same variables as backend/.env.example (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, JWT_SECRET, PORT)
5. Run the server:
   dart run bin/server.dart

Notes
- Uses packages: shelf, shelf_router, postgres, dotenv, dart_jsonwebtoken, bcrypt
- Implemented endpoints: /health, /api/auth/(register,login,verify), /api/patient/*, /api/doctor/*, /api/admin/*

This is a starting implementation — expand controllers/services as needed.

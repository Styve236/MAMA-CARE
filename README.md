# 🏥 MamaCare - Plateforme Complète de Suivi Maternal

**MamaCare** : application mobile de suivi de la santé maternelle avec trois rôles (patiente, médecin, admin), messagerie, alertes médicales par IA, rendez-vous et rappels.

---

## 📋 Structure du Projet

```
MAMACAREV1/
├── mamacare/frontend/mama_care/           # Application Flutter (patiente, médecin, admin)
│   ├── lib/
│   │   ├── admin/                         # 🔐 Module Admin (comptes, attribution, statistiques, logs)
│   │   ├── medecin/                       # 👨‍⚕️ Module Médecin (dashboard, alertes, patientes, messagerie)
│   │   ├── patiente/                      # 👩‍⚕️ Module Patiente (dashboard, télémesure, messagerie, rappels, chat IA)
│   │   ├── services/api_client.dart       # Client HTTP de l'API (tous les endpoints)
│   │   ├── shared/                        # Widgets réutilisables (ChatBubble, ...)
│   │   └── main.dart                      # Point d'entrée + routes
│   ├── backend/                           # 🖥️ Backend Dart (shelf) — API REST
│   │   ├── bin/server.dart                # Point d'entrée du serveur
│   │   ├── bin/migrate.dart               # Applique les migrations SQL
│   │   ├── lib/router.dart                # Montage des routes /api/*
│   │   ├── lib/routes/                    # auth, patient, doctor, admin, notifications, chat
│   │   ├── lib/utils/                     # gemini.dart (IA), jwt, hash, env, json_safe
│   │   ├── lib/config/database.dart       # Connexion PostgreSQL (pooler Supabase)
│   │   ├── lib/models/schema.sql          # Schéma complet (référence)
│   │   ├── migrations/                    # 001..004 migrations versionnées
│   │   └── pubspec.yaml
│   ├── vercel.json                        # Config déploiement frontend (Vercel)
│   ├── start_app.ps1 / start_backend.ps1  # Scripts de lancement
│   └── pubspec.yaml
├── README.md                              # Ce fichier
├── FILES_INDEX.md                         # Index actualisé des fichiers du projet
└── RAPPORT_ANALYSE.md                     # Analyse du projet (document historique)
```

> Les anciens backends `backend_legacy/` et `server/` (remplacés par `backend/`) ont été supprimés.

---

## 🚀 Démarrage Rapide

### 1️⃣ Prérequis
- **Dart SDK** + **Flutter SDK** ([flutter.dev](https://flutter.dev/get-started/install))
- Une base **PostgreSQL** (Supabase recommandée : connexion via le pooler)
- Clé **Gemini API** (optionnelle mais nécessaire pour l'IA / le chatbot)

### 2️⃣ Base de données (Supabase)
1. Créer le projet Supabase et récupérer la chaîne de connexion pooler :
   `postgres.unwgionfobojsvrefcsn@aws-0-eu-central-1.pooler.supabase.com:5432/postgres`
2. Appliquer les migrations :
```bash
cd mamacare/frontend/mama_care/backend
# Définir les variables d'environnement (voir ci-dessous) puis :
dart run bin/migrate.dart
```

### 3️⃣ Configurer le backend
```env
# mamacare/frontend/mama_care/backend/.env
DB_HOST=aws-0-eu-central-1.pooler.supabase.com
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres.<project_ref>
DB_PASSWORD=<mot_de_passe_supabase>
JWT_SECRET=<secret_jwt>
PORT=3000
GEMINI_API_KEY=<clé_gemini>          # IA : analyse pré-alerte + chatbot
```

### 4️⃣ Démarrer le backend
```bash
cd mamacare/frontend/mama_care/backend
dart run bin/server.dart
# ✓ API sur http://localhost:3000  (health : GET /health)
```

### 5️⃣ Démarrer le frontend
```bash
cd mamacare/frontend/mama_care
flutter pub get
flutter run
```

Pour pointer le frontend vers un backend distant (ex. Render) :
```bash
flutter run --dart-define=API_BASE_URL=https://<backend-render>.onrender.com
```

---

## 🔑 Comptes de démonstration

| Rôle | Email | Mot de passe |
|------|-------|--------------|
| Admin | `admin@mamacare.com` | `admin123` |
| Patiente | Inscription via l'écran d'inscription | — |
| Médecin | Créé par l'admin | — |

---

## 🔌 Endpoints API

En-tête d'auth requis : `Authorization: Bearer <token>`

### Authentification (`/api/auth/`)
```
POST   /api/auth/register     - Inscription (patiente)
POST   /api/auth/login        - Connexion
GET    /api/auth/verify       - Vérification du token
```

### Patiente (`/api/patient/`)
```
GET    /profile               - Profil
PATCH  /profile               - Modifier le profil
GET    /telemetry             - Historique des mesures
POST   /telemetry             - Enregistrer une mesure (+ analyse IA pré-alerte)
GET    /appointments          - Rendez-vous
POST   /appointments          - Réserver un rendez-vous
GET    /messages              - Conversation avec le médecin (doctor + messages)
POST   /messages              - Envoyer un message (médecin affecté requis)
GET    /reminders             - Liste des rappels
POST   /reminders             - Créer un rappel
PATCH  /reminders/<id>        - Marquer un rappel fait
DELETE /reminders/<id>        - Supprimer un rappel
```

### Médecin (`/api/doctor/`)
```
GET    /profile               - Profil
PATCH  /profile               - Modifier le profil
GET    /patients              - Patientes affectées
GET    /patients/<id>         - Détail patiente + télémesure + alerte
GET    /alerts                - Alertes IA
GET    /alerts/unread-count   - Nombre d'alertes non lues
PATCH  /alerts/<id>/read      - Marquer une alerte lue
GET    /stats                 - Statistiques (patientes, alertes, messages)
GET    /messages              - Threads de messagerie (avec non-lus)
GET    /messages/<patientUserId> - Conversation complète
POST   /messages              - Envoyer un message à une patiente
POST   /messages/<patientUserId>/read - Marquer la conversation lue
```

### Admin (`/api/admin/`)
```
GET    /stats                          - Statistiques globales
GET    /doctors                        - Liste des médecins (avec charge)
POST   /doctors                        - Créer un médecin
PATCH  /doctors/<id>/status            - Activer / suspendre / désactiver
GET    /patients                       - Liste des patientes
PATCH  /patients/<id>/status           - Activer / suspendre / désactiver
PATCH  /patients/<userId>/assign-doctor - Attribuer un médecin à une patiente ({doctorId|null})
GET    /activity-logs                  - Journal d'audit
```

### Notifications (`/api/notifications/`) & Chat IA (`/api/chat/`)
```
GET    /api/notifications/          - Notifications
GET    /api/notifications/unread-count
POST   /api/notifications/<id>/read
POST   /api/notifications/read-all
POST   /api/chat/                   - Chatbot IA ({message}) → {reply}
```

---

## 🤖 Intelligence Artificielle

- **Analyse pré-alerte** : `POST /api/patient/telemetry` envoie les constantes vitales à **Gemini** ; si l'analyse est `critical`, une alerte est créée et transmise au médecin (champ `details` JSONB).
- **Chatbot** : `POST /api/chat/` avec un suivi grossesse contextuel.
- **Modèles Gemini** : chaîne de repli automatique (`gemini-3.6-flash` → `gemini-3.5-flash` → lite → preview) en cas de quota 429 / saturation 503.
- **Important** : `GEMINI_API_KEY` n'est pas commitée. Sans clé, le chatbot refuse et les alertes IA sont `null`.

---

## 🗄️ Base de Données (tables)

`users`, `doctors`, `patients`, `telemetry`, `appointments`, `messages`, `alerts` (+`details` JSONB), `patient_reminders`, `notifications`, `chatbot_conversations`, `activity_logs`, `statistics`, `admin_actions`, plus `schema_migrations` (suivi des migrations).

---

## 🔐 Sécurité

- JWT (7 jours) avec rôles (`patiente` / `medecin` / `admin`) et contrôles par route.
- Mots de passe hachés (`HashService`).
- Requêtes PostgreSQL paramétrées (anti-injection SQL).
- Clés et secrets uniquement via variables d'environnement.

---

## 🚀 Déploiement

### Backend → Render
1. Service Web pointant vers `mamacare/frontend/mama_care/backend` (build `dart pub get` + start `dart run bin/server.dart`).
2. Variables d'environnement : `DB_*`, `JWT_SECRET`, `PORT`, **`GEMINI_API_KEY`** (sinon l'IA n'est pas active).
3. Sans `GEMINI_API_KEY`, l'app affiche « l'assistant IA n'est pas encore configuré ».

### Frontend → Vercel
1. Framework Flutter ; `vercel.json` positionne `buildCommand: flutter build web` et `outputDirectory: build/web`.
2. Dans Vercel, définir la variable d'environnement **`API_BASE_URL`** = URL du backend Render.
3. L'app lit `API_BASE_URL` via `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000')`.

---

## 🧪 Tests & Qualité

```bash
# Backend
cd mamacare/frontend/mama_care/backend && dart analyze

# Frontend
cd mamacare/frontend/mama_care && flutter analyze lib
```

- Les scénarios de bout en bout (inscription → attribution → messagerie → RDV → rappels → alerte IA) sont testés manuellement via l'API.

---

**Version**: 2.0.0
**Statut**: ✅ Fonctionnel (backend Dart, IA Gemini, messagerie, rappels, attribution admin)
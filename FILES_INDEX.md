📋 INDEX COMPLET DES FICHIERS - MAMACARE (version actuelle)

═══════════════════════════════════════════════════════════════════════════════
📦 RACINE DU PROJET (docs)
═══════════════════════════════════════════════════════════════════════════════

1. README.md
   📖 Guide global du projet (version actuelle : backend Dart, IA Gemini)
   └─ Structure, démarrage, endpoints, déploiement Render/Vercel

2. FILES_INDEX.md
   📋 Ce fichier — index des fichiers réels du projet

3. RAPPORT_ANALYSE.md
   📊 Analyse historique du projet (document d'époque, certaines parties obsolètes)

4. START_HERE.md
   🚀 Ancien guide de démarrage (document d'époque, remplacé par README.md)

5. INTEGRATION_GUIDE.md / BEST_PRACTICES.md / PROJECT_SUMMARY.txt
   📚 Documents historiques conservés à titre de référence

═══════════════════════════════════════════════════════════════════════════════
📱 APPLICATION FLUTTER — mamacare/frontend/mama_care/
═══════════════════════════════════════════════════════════════════════════════

LIB/ (racine)
├── main.dart                  # Point d'entrée + table de routes (login, dashboards, écrans)
├── login_screen.dart          # Écran de connexion
├── welcome_screen.dart        # Écran d'accueil
├── notifications_screen.dart  # Notifications push (liste + marquage lu)

LIB/ADMIN/ (module admin)
├── admin_dashboard_screen.dart          # Dashboard admin (cartes, navigation)
├── admin_account_management_screen.dart # Hub de gestion des comptes
├── admin_patient_accounts_screen.dart   # Liste/actions des comptes patientes
├── admin_doctor_accounts_screen.dart    # Liste/actions des comptes médecins
├── admin_assign_doctor_screen.dart      # Attribution médecin↔patiente (auto-charge API)
├── admin_global_statistics_screen.dart  # Statistiques globales
└── admin_activity_log_entry_screen.dart # Journal d'audit (activity logs)

LIB/MEDECIN/ (module médecin)
├── doctor_dashboard_mobile.dart   # Dashboard médecin (nav : patientes/alertes/messages/profil)
├── doctor_alerts_center.dart      # Centre d'alertes IA (liste + lecture)
├── doctor_messages_list.dart      # Threads de messagerie (API réelle, badges non-lus)
├── doctor_conversation_screen.dart# Conversation avec une patiente (envoi/réception)
├── doctor_patiente_detail.dart    # Détail d'une patiente (profil + télémesure + alerte)
├── doctor_profile_screen.dart     # Édition du profil médecin
└── widgets_patient_list_tab.dart  # Liste des patientes affectées

LIB/PATIENTE/ (module patiente)
├── dashboard.dart               # Dashboard patiente (nav : santé/messagerie/RDV/profil/IA)
├── telemetry_input.dart         # Saisie constantes vitales (poids, TA, glycémie...)
├── stats_screen.dart            # Statistiques santé (historique télémesure)
├── doctor_messaging.dart        # Messagerie avec le médecin (API réelle)
├── appointments_reminders_screen.dart # Rendez-vous + rappels (création, coche, suppression)
├── patiente_profile_screen.dart # Profil patiente (lecture)
├── profil_config.dart           # Édition du profil patiente (grossesse, groupes sanguin...)
├── ia_chatbot_screen.dart       # Chatbot IA Gemini
└── register_patiente.dart       # Inscription patiente

LIB/SERVICES / LIB/SHARED
├── services/api_client.dart     # Client HTTP centralisé (tous les endpoints, jwt bearer)
└── shared/chat_bubble.dart      # Bulle de message réutilisable (patiente + médecin)

PUBSPEC & CONFIG FLUTTER
├── pubspec.yaml                 # Dépendances (http, table_calendar, shared_preferences...)
├── vercel.json                  # Config Vercel (build web + outputDirectory build/web)
├── start_app.ps1 / start_backend.ps1  # Scripts de lancement
└── android/ ios/ web/ macos/ linux/ windows/ test/  # Plateformes Flutter standards

═══════════════════════════════════════════════════════════════════════════════
🖥️ BACKEND DART — mamacare/frontend/mama_care/backend/
═══════════════════════════════════════════════════════════════════════════════

BIN/
├── server.dart        # Point d'entrée serveur shelf (port par défaut 3000)
└── migrate.dart       # Applique les migrations 001..004 (suivi schema_migrations)

LIB/
├── router.dart            # Montage des routes : /api/auth, /api/patient, /api/doctor,
│                          # /api/admin, /api/notifications, /api/chat + / et /health
├── config/database.dart   # Connexion PostgreSQL (pooler Supabase)
├── models/schema.sql      # Schéma complet de référence (toutes les tables)
├── models/user.dart       # Modèle utilisateur (création, tokens)
├── routes/auth.dart       # register, login, verify
├── routes/patient.dart    # profile, telemetry, appointments, messages, reminders
├── routes/doctor.dart     # profile, patients, alerts, stats, messages
├── routes/admin.dart      # stats, doctors, patients, status, assign-doctor, activity-logs
├── routes/notifications.dart # notifications, unread-count, read, read-all
├── routes/chat.dart       # POST / (chatbot Gemini)
└── utils/
    ├── env.dart        # Lecture des variables d'environnement
    ├── hash.dart       # Hachage des mots de passe
    ├── jwt.dart        # Émission / vérification des tokens JWT
    ├── json_safe.dart  # Sérialisation JSON (DateTime, etc.)
    └── gemini.dart     # Appel Gemini : kGeminiModels (repli 429/503), analyse télémesure

MIGRATIONS/ (SQL versionné — appliquer via `dart run bin/migrate.dart`)
├── 001_initial_schema.sql        # Tables de base (users, patients, doctors, telemetry,
│                                 # appointments, messages, alerts, notifications,
│                                 # chatbot_conversations, statistics, admin_actions)
├── 002_statistics_admin_actions.sql
├── 003_ia_alerts.sql             # alerts.details JSONB + index non-lus
└── 004_patient_reminders.sql     # Table patient_reminders

RACINE BACKEND
├── schema.sql          # Copie du schéma de référence (lib/models/schema.sql)
├── pubspec.yaml        # Dépendances (shelf, shelf_router, postgres, http, crypto...)
└── README.md           # Instructions backend

═══════════════════════════════════════════════════════════════════════════════
🗄️ TABLES POSTGRESQL (13 métier + schema_migrations)
═══════════════════════════════════════════════════════════════════════════════

users, doctors, patients, telemetry, appointments, messages, alerts,
patient_reminders, notifications, chatbot_conversations, activity_logs,
statistics, admin_actions, schema_migrations

═══════════════════════════════════════════════════════════════════════════════
🧹 SUPPRIMÉS
═══════════════════════════════════════════════════════════════════════════════

- backend_legacy/ (ancien backend Dart dupliqué, remplacé par backend/)
- server/ (autre copie de backend, remplacé par backend/)
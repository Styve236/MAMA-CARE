# 🚀 START HERE — MAMACARE

Guide de démarrage **actuel** du projet (backend Dart + Flutter + Supabase + IA Gemini).

> Les anciens backends `backend_legacy/` et `server/` ont été supprimés. Le seul backend est `mamacare/frontend/mama_care/backend/`.

---

## 📦 TL;DR

```
Dossier backend   : mamacare/frontend/mama_care/backend
Dossier frontend  : mamacare/frontend/mama_care
Port API          : 3000
Base de données   : PostgreSQL (Supabase, pooler)
```

---

## 🚀 DÉMARRAGE RAPIDE

1. **Lire le README** : `README.md` (guide complet, endpoints, déploiement).

2. **Base de données** (migrations) :
   ```bash
   cd mamacare/frontend/mama_care/backend
   dart run bin/migrate.dart     # applique migrations/001..004
   ```

3. **Variables d'environnement backend** (`DB_*`, `JWT_SECRET`, `PORT`, `GEMINI_API_KEY`).
   Sans `GEMINI_API_KEY`, l'IA (analyse pré-alerte + chatbot) est inactive.

4. **Démarrer le backend** :
   ```bash
   cd mamacare/frontend/mama_care/backend
   dart run bin/server.dart
   # ✓ API sur http://localhost:3000 — tester : GET /health
   ```

5. **Démarrer le frontend** :
   ```bash
   cd mamacare/frontend/mama_care
   flutter pub get
   flutter run
   ```

---

## 🔑 COMPTES

| Rôle | Email | Mot de passe |
|------|-------|--------------|
| Admin | `admin@mamacare.com` | `admin123` |
| Médecin | créé par l'admin (module Admin) | défini à la création |
| Patiente | via l'écran d'inscription | définie à l'inscription |

---

## ✅ CHECKLIST RAPIDE

- [ ] Migrations appliquées (`dart run bin/migrate.dart`)
- [ ] `dart run bin/server.dart` répond sur `http://localhost:3000`
- [ ] `flutter run` lance l'application
- [ ] Admin peut créer un médecin, valider une patiente, attribuer un médecin
- [ ] Patiente : télémesure → alerte IA chez le médecin (si `GEMINI_API_KEY` définie)
- [ ] Messagerie médecin ↔ patiente, rendez-vous, rappels opérationnels

---

## 🚀 DÉPLOIEMENT (résumé)

- **Backend → Render** : variables `DB_*`, `JWT_SECRET`, `PORT`, `GEMINI_API_KEY`. Sans la clé Gemini, l'IA n'est pas configurée.
- **Frontend → Vercel** : `vercel.json` (build `flutter build web`, output `build/web`) + variable d'environnement `API_BASE_URL` = URL Render.

Détails complets : voir `README.md`.

---

**Version**: 2.0.0  
**Statut**: ✅ Le projet est fonctionnel avec les fonctionnalités dynamiques (IA, messagerie, rappels, attribution admin).
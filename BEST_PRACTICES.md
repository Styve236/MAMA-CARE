🏥 MAMACARE - GUIDE DES BONNES PRATIQUES & CHECKLIST FINALE

═══════════════════════════════════════════════════════════════════════════════
✅ CHECKLIST DE CONFIGURATION
═══════════════════════════════════════════════════════════════════════════════

AVANT DE DÉMARRER LE DÉVELOPPEMENT:

□ ENVIRONNEMENT SYSTÈME
  □ Node.js 16+ installé (vérifier: node -v)
  □ npm 8+ installé (vérifier: npm -v)
  □ PostgreSQL 12+ installé (vérifier: psql --version)
  □ Git configuré (optionnel)
  □ Code editor (VS Code recommandé)

□ PRÉREQUIS BACKEND
  □ Dossier backend cloné/créé
  □ npm install exécuté (npm install)
  □ .env.example copié vers .env (cp .env.example .env)
  □ Paramètres .env configurés
  □ Base de données créée (createdb mamacare_db)

□ CONFIGURATION DATABASE
  □ PostgreSQL service démarré
  □ Base de données mamacare_db existe
  □ Utilisateur postgresql configuré
  □ Permissions correctes

□ VARIABLES D'ENVIRONNEMENT (.env)
  □ PORT défini (défaut: 3000)
  □ NODE_ENV configuré (development/production)
  □ DB_HOST, DB_PORT, DB_NAME configurés
  □ DB_USER, DB_PASSWORD configurés
  □ JWT_SECRET défini (fort pour production!)
  □ Autres clés API configurées (optionnel)

□ TEST INITIAL
  □ npm run dev exécuté sans erreurs
  □ Message "API running on http://localhost:3000" affiché
  □ Schéma base de données créé
  □ curl http://localhost:3000/health retourne OK

═══════════════════════════════════════════════════════════════════════════════
📐 BONNES PRATIQUES DE CODE
═══════════════════════════════════════════════════════════════════════════════

ARCHITECTURE:
✅ Séparation des préoccupations
   - Controllers: Logique métier
   - Services: Logique réutilisable
   - Models: Accès aux données
   - Routes: Définition endpoints
   - Middleware: Authentification, validation

✅ Modularité
   - Un fichier = une responsabilité
   - Fonctions petites et cohérentes
   - Réutilisation du code

✅ Nommage Cohérent
   - Classes: PascalCase (UserService)
   - Fonctions: camelCase (getUserById)
   - Fichiers: camelCase ou PascalCase
   - Constants: UPPER_SNAKE_CASE

SÉCURITÉ:
✅ Authentification
   - JWT tokens valides 7 jours
   - Refresh tokens (optionnel)
   - Logout côté client (supprimer token)

✅ Autorisation
   - RBAC sur tous les endpoints
   - Vérification user_id vs resource owner
   - Audit logging des actions admin

✅ Données
   - Mot de passe: toujours hashé (bcrypt)
   - Validation ALL input (Joi)
   - SQL injection: requêtes paramétrées
   - XSS: output encoding

✅ Communication
   - HTTPS en production (SSL/TLS)
   - CORS strictement configuré
   - Headers sécurité (Helmet)
   - Rate limiting

PERFORMANCE:
✅ Base de Données
   - Indices sur colonnes fréquemment cherchées
   - Lazy loading pour relations
   - Pagination pour gros datasets
   - Connection pooling

✅ API
   - Response compression (gzip)
   - Caching approprié
   - Requêtes optimisées
   - Pas N+1 queries

✅ Code
   - Éviter requêtes en boucles
   - Promise.all() pour requêtes parallèles
   - Async/await plutôt que callbacks

LOGGING:
✅ Production
   - Log erreurs critiques
   - Log accès utilisateurs
   - Log modifications données
   - Pas de données sensibles dans logs

✅ Développement
   - console.log() temporaires seulement
   - Morgan pour HTTP logging
   - Custom requestLogger

ERROR HANDLING:
✅ Controllers
   - Try/catch sur opérations BD
   - Messages d'erreur clairs
   - HTTP status codes corrects
   - Pas de stack trace aux clients

✅ Validation
   - Valider TOUS les inputs
   - Messages d'erreur spécifiques
   - Types de données correctes
   - Formats valides

═══════════════════════════════════════════════════════════════════════════════
🚀 GUIDE DE DÉVELOPPEMENT
═══════════════════════════════════════════════════════════════════════════════

POUR AJOUTER UN NOUVEL ENDPOINT:

1. DÉFINIR LA ROUTE
   Fichier: src/routes/[module].js
   
   Exemple:
   ```javascript
   router.get('/resource/:id', authenticateToken, authorizeRole('role'), 
     validateParams(idSchema), ResourceController.getById);
   ```

2. CRÉER LE CONTROLLER
   Fichier: src/controllers/[Module]Controller.js
   
   ```javascript
   static async getById(req, res) {
     try {
       const { id } = req.params;
       const data = await Service.getById(id);
       return res.status(200).json({ data });
     } catch (error) {
       return res.status(500).json({ message: error.message });
     }
   }
   ```

3. CRÉER/UTILISER UN SERVICE
   Fichier: src/services/[Feature]Service.js
   
   ```javascript
   static async getById(id) {
     const query = 'SELECT * FROM table WHERE id = $1';
     const result = await pool.query(query, [id]);
     return result.rows[0];
   }
   ```

4. AJOUTER UNE VALIDATION (si nécessaire)
   Fichier: src/routes/[module].js
   
   ```javascript
   const getByIdSchema = Joi.object({
     id: Joi.number().required()
   });
   
   router.get('/:id', validateParams(getByIdSchema), ...);
   ```

5. TESTER L'ENDPOINT
   - Postman: créer nouvelle requête
   - cURL: tester manuellement
   - Jest: ajouter test unitaire

═══════════════════════════════════════════════════════════════════════════════
🔍 DEBUGGING
═══════════════════════════════════════════════════════════════════════════════

PROBLÈME: Connection Database Timeout
SOLUTION:
  1. Vérifier PostgreSQL running: psql postgres
  2. Vérifier DB existe: \l (dans psql)
  3. Vérifier .env credentials
  4. Redémarrer service: pg_ctl restart

PROBLÈME: JWT Token Invalid
SOLUTION:
  1. Vérifier JWT_SECRET dans .env
  2. Vérifier format: "Bearer <token>"
  3. Vérifier expiration token
  4. Copier nouveau token après login

PROBLÈME: 403 Forbidden Error
SOLUTION:
  1. Vérifier user role (admin/medecin/patiente)
  2. Vérifier authenticateToken exécuté
  3. Vérifier authorizeRole correct
  4. Logs: console.log(req.user)

PROBLÈME: CORS Error
SOLUTION:
  1. Vérifier CORS config dans server.js
  2. Vérifier origin autorisé
  3. Vérifier headers supportés
  4. Vérifier credentials: true si cookie

PROBLÈME: Validation Error 400
SOLUTION:
  1. Vérifier schéma Joi
  2. Vérifier données envoyées
  3. Vérifier types données
  4. Lire message d'erreur

═══════════════════════════════════════════════════════════════════════════════
📚 CONVENTIONS DE CODE
═══════════════════════════════════════════════════════════════════════════════

COMMENTAIRES:
✅ Utiliser pour logique complexe
✅ Expliquer le POURQUOI, pas le QUOI
✅ Maintenir à jour avec code

Bon:
```javascript
// Récupérer patientes par médecin assigné
// Filtered par statut actif pour perf
const getPatients = (doctorId) => { ... }
```

Mauvais:
```javascript
// Boucle sur patients
// Ajouter à array
for (let i = 0; i < patients.length; i++) { ... }
```

ERREURS À ÉVITER:

❌ Hardcoder secrets
```javascript
// MAUVAIS
const dbPassword = 'password123';
```

✅ Utiliser variables d'env
```javascript
// BON
const dbPassword = process.env.DB_PASSWORD;
```

❌ Pas gérer erreurs
```javascript
// MAUVAIS
const user = await User.findById(id);
```

✅ Toujours gérer
```javascript
// BON
try {
  const user = await User.findById(id);
} catch (error) {
  return res.status(500).json({ message: error.message });
}
```

❌ N+1 Queries
```javascript
// MAUVAIS
const patients = await Patient.findAll();
for (let p of patients) {
  const doctor = await Doctor.findById(p.doctor_id); // ❌ Boucle!
}
```

✅ Optimiser
```javascript
// BON
const query = `
  SELECT p.*, d.* FROM patients p
  LEFT JOIN doctors d ON p.doctor_id = d.id
`;
```

═══════════════════════════════════════════════════════════════════════════════
📊 TESTS ESSENTIELS
═══════════════════════════════════════════════════════════════════════════════

TESTER AVEC POSTMAN/INSOMNIA:

1. AUTHENTIFICATION
   ✅ Register: POST /api/auth/register (invalid data)
   ✅ Register: POST /api/auth/register (duplicate email)
   ✅ Register: POST /api/auth/register (valid data)
   ✅ Login: POST /api/auth/login (invalid credentials)
   ✅ Login: POST /api/auth/login (valid credentials)
   ✅ Verify: GET /api/auth/verify (sans token)
   ✅ Verify: GET /api/auth/verify (avec token)

2. AUTORISATION
   ✅ Patient accès /api/doctor/* → 403
   ✅ Doctor accès /api/admin/* → 403
   ✅ Admin accès /api/* → 200

3. DATA VALIDATION
   ✅ Email invalid → 400
   ✅ Password trop court → 400
   ✅ Role invalid → 400
   ✅ Missing required fields → 400

4. ENDPOINTS CRITIQUES
   ✅ Patient telemetry recording
   ✅ Doctor alerts fetching
   ✅ Admin user management
   ✅ Appointment booking

5. ERROR CASES
   ✅ Database error → 500
   ✅ Not found → 404
   ✅ Duplicate entry → 400
   ✅ Server error → 500

═══════════════════════════════════════════════════════════════════════════════
🚀 DÉPLOIEMENT PRODUCTION
═══════════════════════════════════════════════════════════════════════════════

AVANT DÉPLOIEMENT:

□ Code Review
  □ Tests complétés
  □ Pas de console.log()
  □ Pas de credentials en dur
  □ Erreurs gérées
  □ Logs appropriés

□ Sécurité
  □ JWT_SECRET changé (très fort)
  □ DB_PASSWORD changé
  □ CORS configuré proprement
  □ Rate limiting activé
  □ HTTPS/SSL certificat
  □ Headers sécurité vérifiés

□ Performance
  □ Database indices
  □ Connection pooling
  □ Compression gzip
  □ Caching configuré
  □ Queries optimisées

□ Monitoring
  □ Logging configured
  □ Error tracking (Sentry)
  □ Performance monitoring
  □ Database backups
  □ Health checks

DÉPLOIEMENT OPTIONS:

HEROKU:
```bash
heroku create mamacare-api
heroku addons:create heroku-postgresql:standard-0
git push heroku main
```

DOCKER:
```bash
docker build -t mamacare-api .
docker run -p 3000:3000 -e NODE_ENV=production mamacare-api
```

AWS ELASTIC BEANSTALK:
```bash
eb create mamacare-api-prod
eb deploy
```

GOOGLE CLOUD RUN:
```bash
gcloud run deploy mamacare-api \
  --source . \
  --platform managed \
  --region us-central1
```

═══════════════════════════════════════════════════════════════════════════════
🎯 CHECKLIST AVANT LIVRAISON
═══════════════════════════════════════════════════════════════════════════════

CODE:
□ Compilé sans erreurs
□ Linter passé (npm run lint)
□ Tests passés (npm test)
□ Code comments added
□ No console.log/debugger
□ Security reviews done
□ Dependencies up to date

DOCUMENTATION:
□ README.md complet
□ API docs à jour
□ Installation steps clairs
□ Examples inclus
□ Troubleshooting guide
□ Environment variables listées

TESTS:
□ All endpoints tested
□ Happy path covered
□ Error cases covered
□ Authentication tested
□ Authorization tested
□ Edge cases handled

DÉPLOIEMENT:
□ .env.example up to date
□ docker-compose tested
□ Dockerfile tested
□ Database migrations ready
□ Backups configured
□ Monitoring setup

LIVE CHECK:
□ API health check working
□ Database connected
□ No error logs
□ Performance acceptable
□ Load testing passed
□ Security scan passed

═══════════════════════════════════════════════════════════════════════════════
📞 RESSOURCES UTILES
═══════════════════════════════════════════════════════════════════════════════

DOCUMENTATION OFFICIELLE:
• Express.js:     https://expressjs.com/
• PostgreSQL:     https://www.postgresql.org/docs/
• Node.js:        https://nodejs.org/en/docs/
• JWT:            https://jwt.io/
• Joi:            https://joi.dev/api/
• Bcrypt:         https://github.com/kelektiv/node.bcrypt.js

OUTILS DE DÉVELOPPEMENT:
• Postman:        https://www.postman.com/
• Insomnia:       https://insomnia.rest/
• DBeaver:        https://dbeaver.io/
• VS Code:        https://code.visualstudio.com/

TUTORIALS:
• Express + PostgreSQL: https://www.youtube.com/...
• REST API Design:      https://www.youtube.com/...
• JWT Authentication:   https://www.youtube.com/...

═══════════════════════════════════════════════════════════════════════════════
✨ CONCLUSION
═══════════════════════════════════════════════════════════════════════════════

Vous avez maintenant:
✅ Backend complet et fonctionnel
✅ Documentation détaillée
✅ Bonnes pratiques intégrées
✅ Sécurité en place
✅ Structure scalable

Prochaines étapes:
1. Intégrer le frontend
2. Tester complètement
3. Configurer production
4. Monitorer et optimiser

Besoin d'aide?
→ Consultez la documentation
→ Vérifiez les exemples
→ Utilisez les outils de debug

═══════════════════════════════════════════════════════════════════════════════

Bon développement! 🚀

MamaCare Team | Version 1.0.0 | 31 Août 2024

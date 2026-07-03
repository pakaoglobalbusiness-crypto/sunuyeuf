# Sunuyeuf 🏠🚗

Marketplace mobile de location de villas et de voitures au Sénégal.
Inspirée d'Airbnb, pensée pour les réalités locales : paiement Wave / Orange
Money / Free Money / carte, connexion par OTP SMS, confiance par KYC et
séquestre des fonds.

## Structure du projet

| Dossier | Rôle | Techno |
|---|---|---|
| `backend/` | API REST (monolithe modulaire) | NestJS + Prisma + SQLite (PostgreSQL en prod) |
| `admin/` | Back-office web (modération, KYC, litiges, stats) | React + Vite + TypeScript |
| `mobile/` | Application mobile (Android / iOS / web) | Flutter |

## Démarrage rapide (dev)

### 1. API backend — port 3000

```bash
cd backend
npm install
npx prisma db push        # crée la base SQLite
npm run seed              # données de démo (annonces + comptes)
npm run build && npm start
```

### 2. Back-office admin — port 5180

```bash
cd admin
npm install
npm run dev -- --port 5180
```

Connexion : `+221770000000` (admin). Le code OTP s'affiche à l'écran en mode dev.

### 3. App mobile — Flutter

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd mobile
flutter run -d web-server --web-port=5181   # test navigateur
flutter run                                  # émulateur / téléphone branché
```

Sur téléphone physique, pointer l'API vers l'IP locale :
`flutter run --dart-define=API_URL=http://192.168.x.x:3000/api/v1`

## Comptes de démo (seed)

| Rôle | Téléphone |
|---|---|
| Admin | `+221 77 000 00 00` |
| Propriétaires | `+221 77 111 11 11` · `+221 77 222 22 22` · `+221 77 333 33 33` |
| Locataire | `+221 77 444 44 44` |

En mode dev, le code OTP est renvoyé dans la réponse API et affiché dans
l'interface (`devCode`) — aucun SMS réel n'est envoyé.

## Fonctionnalités implémentées (MVP)

- **Auth** : téléphone + OTP (simulé en dev), JWT 30 jours, 5 tentatives max.
- **Annonces** : villas et voitures, création guidée en 5 étapes, photos,
  modération manuelle avant publication, calendrier de disponibilités.
- **Recherche** : type, ville, budget, dates, texte libre, tri, pagination.
- **Réservations** : machine à états complète (`requested → accepted → paid →
  ongoing → completed / cancelled / disputed`), réservation instantanée,
  politique d'annulation figée à la réservation avec barème de remboursement.
- **Paiements** : agrégateur simulé (Wave, Orange Money, Free Money, carte)
  avec webhook de confirmation ; commission plateforme **10 %** côté
  propriétaire ; séquestre puis versement programmé à J+1 ; remboursements.
- **Voitures** : chauffeur, kilométrage, lieu de remise, caution, état des
  lieux photo remise/retour qui pilote les statuts.
- **Messagerie** interne liée à la réservation (numéros masqués), avis
  bidirectionnels après séjour, litiges avec arbitrage admin.
- **Back-office** : stats (GMV, commission, top villes), modération, KYC,
  litiges avec remboursement partiel, blocage d'utilisateurs.
- **Confiance** : KYC obligatoire pour publier, localisation exacte révélée
  après paiement uniquement.

## Passage en production — reste à faire

1. **Base de données** : basculer `backend/prisma/schema.prisma` sur
   PostgreSQL + PostGIS (le schéma est compatible) ; verrous de disponibilité
   sur Redis.
2. **Paiements réels** : signer avec PayDunya / CinetPay / Paystack, remplacer
   `PaymentsService` mock (variable `PAYMENT_PROVIDER`), vérifier la signature
   HMAC des webhooks.
3. **SMS réels** : brancher un fournisseur (Orange SMS API, AxiomText, Twilio)
   dans `AuthService` (variable `SMS_PROVIDER`).
4. **Upload de fichiers** : stockage S3 + CDN pour les photos d'annonces et
   documents KYC (actuellement : URLs).
5. **Push** : Firebase Cloud Messaging (les points d'accroche `[Notif mock]`
   sont dans le code).
6. **Sécurité** : rate limiting, HTTPS, secrets en variables d'environnement,
   audit log.
7. **Conformité** : déclaration CDP (loi 2008-12), conservation KYC BCEAO,
   dépôt de marque OAPI, domaine sunuyeuf.sn.

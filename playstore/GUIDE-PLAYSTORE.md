# Publier Gologui sur le Google Play Store

## ✅ Ce qui est déjà prêt (dans ce dossier et sur le Bureau)

| Élément | Emplacement |
|---|---|
| **Bundle signé (AAB)** — à téléverser | `~/Desktop/Gologui.aab` |
| **Clé de signature** — À SAUVEGARDER PRÉCIEUSEMENT | `~/gologui/gologui-upload-key.jks` |
| **Mot de passe de la clé** | `Jv3rxQyP7TViJ1hjiASI` |
| **Icône 512×512** | `playstore/icon-512.png` |
| **Graphique de présentation 1024×500** | `playstore/feature-graphic-1024x500.png` |
| **Politique de confidentialité** | https://gologui-admin.onrender.com/privacy.html |

> ⚠️ **Sans le fichier `.jks` et son mot de passe, vous ne pourrez jamais mettre
> à jour l'app.** Copiez-les sur un cloud privé + une clé USB. Ne les mettez
> jamais sur GitHub (déjà exclus).

## 🧾 Fiche du store (à copier-coller)

**Nom de l'application :** Gologui

**Description courte (80 car. max) :**
Louez villas et voitures partout au Sénégal, en toute confiance.

**Description complète :**
Gologui est la marketplace sénégalaise pour louer un logement ou une voiture,
et pour proposer les vôtres à la location.

Pour les voyageurs et la diaspora :
• Trouvez une villa, une maison, un appartement ou une voiture partout au
  Sénégal (14 régions, filtres par localisation, budget, équipements, marque…).
• Réservez et payez en toute sécurité : Wave, Orange Money, Free Money ou carte.
• Profils vérifiés, avis authentiques, messagerie intégrée.

Pour les propriétaires :
• Publiez votre bien en quelques minutes, gérez vos réservations et vos revenus.
• Recevez vos gains sur Wave, Orange Money ou par virement bancaire.

Gologui prélève une commission de 10 % côté propriétaire sur chaque location.

**Catégorie :** Voyage et infos locales
**E-mail de contact :** contact@gologui.sn (à créer)
**Site web / Politique de confidentialité :** https://gologui-admin.onrender.com/privacy.html

## 📱 Étapes sur la Play Console (à faire par vous)

1. **Créer le compte développeur** : https://play.google.com/console
   → 25 $ une seule fois + vérification d'identité (peut prendre 1–2 jours).

2. **Créer l'application** → « Créer une application » → nom « Gologui »,
   français, application gratuite.

3. **Téléverser le bundle** : menu *Production* → *Créer une release* →
   téléverser `Gologui.aab`. Google gère la signature finale automatiquement
   (« Play App Signing » — acceptez).

4. **Fiche du store** (*Présence sur le Store → Fiche principale*) : coller les
   textes ci-dessus, l'icône 512, le graphique 1024×500, et **au moins 2
   captures d'écran** de téléphone (voir ci-dessous).

5. **Questionnaires obligatoires** :
   - *Classification du contenu* : questionnaire (app tout public).
   - *Sécurité des données* : déclarer les données collectées (nom, téléphone,
     e-mail, photos, localisation) — cf. la politique de confidentialité.
   - *Public cible* : 18 ans et plus (paiements).
   - *Politique de confidentialité* : coller l'URL ci-dessus.

6. **Envoyer pour examen**. Le premier examen prend en général 1 à 7 jours.

## 📸 Captures d'écran (2 minimum, format téléphone)

Le plus simple : installez `Gologui.apk` sur votre téléphone, ouvrez les écrans
Explorer, une fiche d'annonce, le portefeuille, et faites des captures d'écran
natives. Téléversez-les dans la fiche du store.

## 🔴 Avant le vrai lancement (recommandé)

- Passer PayDunya en mode **live** (clés live) et les vrais **SMS** (Orange
  SMS API), sur Render → sunuyeuf-api → Environment.
- Passer l'API Render en plan payant (pas de mise en veille).
- Créer l'adresse **contact@gologui.sn** et le domaine.

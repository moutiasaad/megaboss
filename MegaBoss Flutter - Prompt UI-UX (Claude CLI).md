# MegaBoss — Application Livreur / Pickupeur
## Prompt complet UI/UX pour Claude CLI (Flutter)

> **Comment utiliser ce fichier :** ouvrez Claude CLI à la racine de votre projet Flutter et
> collez les sections une par une (ou le fichier entier). Chaque section est rédigée comme une
> instruction directe à l'agent. Construisez dans l'ordre : **0 → 1 → 2 → 3 → 4 → 5**.
> L'app est **offline-first**, **français par défaut** (FR / AR-RTL / EN), pensée pour un usage
> extérieur rapide (grandes polices, cibles ≥ 48 dp, utilisable avec des gants).

---

## 0 — SETUP DU PROJET

```
Crée une application Flutter "megaboss_driver" (Material 3, null-safety).
Architecture : feature-first + couche data offline-first.

Dépendances pubspec.yaml :
  flutter_riverpod        # state management
  go_router               # navigation + deeplinks (notifications)
  dio                     # client HTTP
  hive / hive_flutter     # cache local + file d'opérations
  flutter_secure_storage  # token d'auth
  connectivity_plus       # détection réseau
  mobile_scanner          # scan code-barres caméra
  geolocator              # position GPS livreur
  google_maps_flutter     # écran Maps / itinéraire
  fl_chart                # graphiques de l'écran Stats
  firebase_messaging      # notifications push (FCM)
  intl                    # i18n + RTL
  google_fonts            # polices (ou bundle les .ttf dans assets/fonts)

Structure des dossiers :
  lib/
    core/        theme/  (colors.dart, typography.dart, spacing.dart, app_theme.dart)
                 network/ (dio, intercepteurs, file de sync offline)
                 widgets/ (composants réutilisables — voir §2)
    features/    auth/  dashboard/  runsheets/  shipments/  scan/
                 pickup/  maps/  calls/  stats/  notifications/  settings/
    l10n/        fr.arb (défaut)  ar.arb  en.arb
    router/      app_router.dart
```

---

## 1 — DESIGN TOKENS (source de vérité)

Crée `lib/core/theme/colors.dart`, `typography.dart`, `spacing.dart`. **Ne jamais coder une
couleur en dur dans un widget — toujours passer par le thème.**

### 1.1 Couleurs

```
Marque
  red        #EE0101   // action primaire, ligne de scan, FAB, statut Échec
  redDark    #C50303   // pressed
  blue       #004E95   // headers, navigation, liens, statut En attente
  blueDark   #003A6F
  blue050    #E8F0F8   // fonds de surbrillance bleus

Encre / structure (neutres)
  ink        #1A1F26   // texte principal
  ink2       #5A6675   // texte secondaire
  ink3       #93A0AF   // texte tertiaire / placeholders
  line       #D6DDE6   // bordures
  line2      #E8ECF2   // séparateurs internes
  surface    #FFFFFF   // cartes
  surface2   #F4F6F9   // fond d'écran (scaffold)
  surface3   #EDF1F6   // chips, champs

Système de statut (CRITIQUE — cohérent sur toute l'app)
  Livré        ok    #1B9E4B  / fond #E6F4EC
  Échec        err   #EE0101  / fond #FCE7E7
  En attente   pend  #004E95  / fond #E8F0F8
  Hors-ligne / Pas de réponse   warn #E08600 / fond #FBF0DD
```

Construis un **ColorScheme** Material 3 : `primary = red`, `secondary = blue`,
`surface = surface`, `background = surface2`, `error = err`. Ajoute une extension
`ThemeExtension` `MbStatusColors` portant ok/err/pend/warn + leurs fonds, pour y accéder via
`Theme.of(context).extension<MbStatusColors>()`.

### 1.2 Typographie

```
Display  : Archivo         (w700/w800) — titres, chiffres, libellés d'action, AppBar
Texte    : Hanken Grotesk  (w400–w700) — corps, listes, descriptions
Mono     : Spline Sans Mono(w500/w600) — n° de suivi, IDs, endpoints, horodatages

Échelle (taille / poids / usage)
  h1   26 / 800  Archivo   titre d'écran d'accueil
  h2   18 / 700  Archivo   titres de carte, nom du livreur
  h3   15 / 700  Archivo   titres de ligne
  body 14 / 400  Hanken    corps
  sub  12 / 500  Hanken    secondaire
  cap  11 / 600  Hanken    UPPERCASE, letterSpacing .04 — labels de champs
  mono 12 / 600  Spline    identifiants & endpoints
  stat 23 / 800  Archivo   grands chiffres KPI

Règle d'accessibilité : aucun texte interactif < 13 px. Respecte textScaleFactor.
```

### 1.3 Espacement, rayons, élévation

```
Espacement (base 4) : 4, 8, 12, 14, 16, 22, 24
Rayons : champ/bouton 11 · carte 13–14 · chip 6–8 · pill 999 · bottom sheet 22 (haut)
Cible tactile minimale : 48 dp (boutons, lignes de liste, items de scan)
Élévation : cartes ombre très douce (0 2 18 -10 rgba(20,40,80,.12)) ;
            FAB ombre rouge teintée ; bottom sheet ombre haute marquée
Bordure standard : 1 px line. Carte « active » : bordure gauche 3 px red.
```

### 1.4 ThemeData

```
Assemble app_theme.dart (light + dark) :
  scaffoldBackgroundColor = surface2
  AppBar : fond blue, texte/icônes blancs, titre Archivo w700, pas d'élévation
  Card   : fond surface, rayon 14, bordure 1px line, ombre douce
  FilledButton (primaire) : fond red, texte blanc Archivo w700, rayon 11, hauteur 48
  OutlinedButton (ghost)  : bordure 1.5 blue, texte blue
  Input  : rempli surface, bordure line, focus bordure blue 1.5, rayon 11
  BottomSheet : rayon haut 22, poignée grise 38×4
  NavigationBar : fond surface, item actif blue, inactif ink3
  SnackBar (toast) : fond ink, texte blanc, icône de statut colorée
Dark : inverse les neutres (fond ~#0E1217, surfaces ~#161C24), garde red/blue/statuts.
```

---

## 2 — COMPOSANTS RÉUTILISABLES (lib/core/widgets)

Génère chaque widget paramétrable, documenté, conforme aux tokens §1 :

```
MbAppHeader        En-tête bleu : logo blanc, salutation + nom, pill de statut livreur,
                   bandeau « N opérations en attente de synchro », bouton cloche.
MbStatusBadge      Pastille de statut (ok/err/pend/warn) : point + libellé, fond teinté.
MbStatPill         Petite tuile chiffre + label (utilisée en grilles de 3).
MbTriProgress      Barre de progression tri-couleur (livrés vert / échecs rouge / restants gris).
MbCard             Carte standard ; variante `accent` = bordure gauche rouge 3 px.
MbChip / MbMono    Chip neutre / texte mono pour IDs & n° de suivi.
MbListRow          Ligne runsheet/manifest : chip n°, titre, badge statut, sous-ligne, mini-progress.
MbShipmentRow      Ligne colis : point de statut, destinataire, adresse courte, montant COD.
MbKeyValue         Ligne icône + label CAP + valeur (bloc destinataire).
MbCodAmount        Encart COD bleu (label + grand montant Archivo) — donnée critique.
MbCallRow          Ligne d'appel : icône colorée (joint/sans rép./injoignable) + durée + rappel tel:.
MbTimeline         Historique vertical à pastilles colorées + horodatage mono.
MbOfflineBanner    Bandeau orange persistant « Hors-ligne » + compteur de file.
MbPrimaryAction    Bouton primaire rouge pleine largeur (action de validation).
MbBottomSheet      Conteneur de feuille : poignée, en-tête (photo + nom + adresse + badge).
MbScanFrame        Viseur caméra : 4 coins blancs + ligne de scan rouge animée.
MbState            États génériques : loading (skeleton shimmer), empty (illustration+texte),
                   error (message + « Réessayer »), offline.
MbTabBar           Barre 5 onglets : Accueil · Runsheets · Pickup · Stats · Profil.
MbFab              FAB rouge « Scanner ».
```

Comportements transverses : **pull-to-refresh** sur toutes les listes ; **skeleton** pendant le
fetch ; toute action terrain est **optimiste** (UI mise à jour immédiatement, opération mise en
file si hors-ligne).

---

## 3 — ÉCRANS (16) — layout détaillé

> Pour chaque écran : route, données chargées, structure de haut en bas, actions, et états
> (Loading / Offline / Empty / Error) là où ils s'appliquent.

### Section 0 — Démarrage

**01 · Splash** — `route /` · `GET /driver/me`
Fond bleu marque plein écran, logo MegaBoss blanc centré, petit loader, version en bas en mono.
Au lancement : lit le token (`flutter_secure_storage`), initialise Hive + thème + langue, valide
le token en silence. Token valide → `/dashboard` ; absent/expiré → `/login`.

**02 · Login** — `route /login` · `POST /driver/login`
Sélecteur de langue FR/AR/EN en haut (bascule RTL pour l'arabe). Logo navy centré. Champ email
(validation format) + champ mot de passe (œil afficher/masquer). Bouton **Se connecter** rouge
pleine largeur. Lien d'aide/support. Succès → stocke token, enregistre device FCM, lance 1ʳᵉ sync.
*États :* bouton en spinner pendant la requête ; message d'erreur rouge sous le formulaire si
identifiants invalides.

### Section 1 — Accueil

**03 · Dashboard** — `route /dashboard` · `GET /runsheets/active`
`MbAppHeader` (logo, nom, pill « Disponible », bandeau synchro, cloche). Corps scrollable :
carte **Runsheet actif** (`MbCard accent` : chip n°, total, grille 3 stats livrés/échecs/restants,
`MbTriProgress`, bouton « Voir le runsheet ») ; carte **Pickup actif** (expéditeur, nb colis,
bouton « Voir le manifest ») ; carte **Aujourd'hui** (3 stats : livraisons, appels, COD collecté).
`MbFab` rouge « Scanner » + `MbTabBar` (Accueil actif). Pull-to-refresh recharge les 3 sources.
*États :* skeleton des cartes ; bandeau offline + compteur ; empty « Aucun runsheet assigné ».

### Section 2 — Livraison

**04 · Liste Runsheets** — `route /runsheets` · `GET /runsheets?period=`
AppBar « Runsheets » + filtre. Segmented control période (Aujourd'hui/Semaine/Mois/Perso).
Liste paginée (scroll infini) de `MbListRow` : n°, libellé, badge statut (En cours/Clôturé),
sous-ligne (x livrés · y échecs · z restants), mini-progress. Bouton « Créer un runsheet ».
Tap ligne → Détail Runsheet.

**05 · Détail Runsheet** — `route /runsheets/:id` · `GET /runsheets/{id}`
En-tête bleu : libellé, n° + statut, deux tuiles (livrés/total, COD total), `MbTriProgress`,
boutons « Voir sur la carte » + « Clôturer ». Liste des colis (`MbShipmentRow`) : destinataire,
adresse courte, COD, point de statut. `MbFab` Scanner (mode Livraison). Clôture **bloquée** si
des colis sont encore en attente → dialog d'avertissement.

**06 · Détail Colis** — `route /shipments/:id` · `GET /shipments/{id}`
En-tête bleu : « Colis », n° de suivi mono, badge statut, **code-barres** affiché. Bloc
destinataire (`MbKeyValue` : nom, téléphone, adresse complète). `MbCodAmount` (montant COD mis en
avant). `MbTimeline` (historique du colis). Liste **Appels liés** (`MbCallRow` + rappel). Barre
d'actions collante en bas : **Appeler** · **Naviguer** (ghost) + action primaire rouge
**Scanner / Marquer livré**.
*États :* skeleton fiche ; offline = action optimiste mise en file ; error = « Réessayer ».

**07 · Scan — Mode Livraison** — `route /scan/delivery` · `POST /scan/delivery`
Caméra plein écran sombre. Barre haute : fermer, libellé de mode (« Confirmation requise »),
torche. `MbScanFrame` (viseur + ligne rouge). À la détection d'un code : **vibration + bip** +
confirmation verte « {n°} détecté ». Ouvre le **bottom sheet de confirmation** → voir 07a/07b/07c.

  **07a · Confirmation — Livré** (`MbBottomSheet`, full sheet)
  Caméra estompée + scrim. En-tête : photo colis, destinataire, adresse, badge « Livré ». Chip n°.
  **Champ COD pré-rempli et éditable** (DH). **Preuve de livraison** : tuiles Photo + Signature
  (optionnelles ou requises selon l'expéditeur). Bouton vert **Confirmer la livraison** + Annuler.
  → enregistre livraison + COD, toast succès, retour au scan suivant.

  **07b · Raison d'échec** (`MbBottomSheet`)
  En-tête mode Échec + n° colis. **Liste de motifs en radio** (sélection unique) : Client absent,
  Colis refusé, Adresse incorrecte, Téléphone injoignable, Livraison reportée (liste pilotée par
  l'API). Commentaire libre + photo de preuve possible. Bouton rouge **Confirmer l'échec** →
  marque le colis échoué, retour au runsheet / scan suivant.

  **07c · Confirmation — Hors-ligne** (`MbBottomSheet`)
  Icône Wi-Fi barrée + `MbOfflineBanner` persistant avec compteur de file. Encart explicatif :
  l'action est stockée localement (Hive) et **repartira automatiquement** au retour du réseau —
  le livreur n'est jamais bloqué. Mêmes actions Livré / Échec / Retour (flux identique en ligne et
  hors-ligne). Toast orange « Enregistré · en attente de synchro » (sans envoi réseau).

**13 · Maps / Itinéraire** — `route /runsheets/:id/map` · `GET /runsheets/{id}`
`google_maps_flutter` plein écran. Marqueurs colorés par statut (livré vert / échec rouge / en
attente bleu) + **position GPS** du livreur (point bleu cerclé rouge). Carte flottante
« Itinéraire optimisé » (TSP local nearest-neighbor : distance + durée estimées, bouton
Optimiser). Tap marqueur → bottom sheet : n° + COD, **Appeler · Naviguer** (Google Maps externe)
+ **Scanner / Marquer livré**.

### Section 3 — Pickup / Collecte

**09 · Liste Pickup (Manifests)** — `route /pickups` · `GET /pickups/active`
AppBar « Pickup » + filtre par expéditeur. Manifests actifs (`MbListRow`) : n° MF, expéditeur,
nb colis à collecter, badge (En cours/À venir/Terminé), mini-progress. Tap → Détail Manifest.

**10 · Détail Manifest** — `route /pickups/:id` · `GET /pickups/{id}`
En-tête bleu : expéditeur, n° MF, « x/y collectés », adresse + bouton appel. Liste **Colis
attendus** : statut (collecté/refusé/en attente) + boutons **Accepter / Refuser** par colis
(`POST /pickups/{id}/shipments/{id}/accept|refuse`). `MbFab` « Scan rapide » → écran 08.

**08 · Scan — Pickup Rapide** — `route /scan/batch` · `POST /scan/batch`
Caméra **ouverte en continu**, scans successifs **sans confirmation** par colis (le plus vite
possible). Gros **compteur** « N colis scannés ». Chaque code : **bip court + tick visuel** + ajout
à une liste latérale ; **idempotent** (un re-scan ne duplique pas). Bouton **Envoyer (N)** → batch
upload ; hors-ligne → tout part dans la file.

**11 · Création Runsheet** — `route /runsheets/new` · `POST /runsheets`
AppBar avec retour. Sélecteur **Expéditeur / source** (dropdown). Liste des colis ajoutés
(`MbShipmentRow` : n°, « scanné » ou « saisi », COD). Deux boutons d'ajout : **Scanner** /
**Saisir** (manuel). Encart **Récapitulatif** (nb colis · COD total). Barre d'action : **Créer le
runsheet** (rouge) → crée puis redirige vers son détail.

### Section 4 — Suivi & Performance

**12 · Historique des appels** — `route /calls` · `GET /calls/stats`
AppBar + filtre (Tous/Joints/Sans rép./Non joign.). Liste `MbCallRow` : destinataire + n° colis,
résultat coloré (vert joint / orange pas de réponse / rouge non joignable), heure + durée mono,
bouton **Rappeler** → `tel:` natif (Android lit `CallLog`, iOS = saisie manuelle du résultat).

**14 · Statistiques** — `route /stats` · `GET /stats?period=`
AppBar « Statistiques ». Chips période (Auj./Semaine/Mois/Perso → date picker). Grille **KPI**
(`MbStatPill` ×4) : livraisons réussies (vert), échecs (rouge), COD collecté (bleu), taux de
joignabilité. **Graphique barres** `fl_chart` (livraisons par jour, barre du jour en rouge).
**Tableau** top 5 des raisons d'échec.

**15 · Notifications** — `route /notifications` · FCM · `POST /device/register`
AppBar avec retour + « Tout effacer / marquer lu ». Liste des notifs (nouveau runsheet, nouveau
manifest, colis ajouté, runsheet clôturé…) : icône colorée par type, libellé, horodatage mono,
**point rouge = non lu**. Tap → **deeplink** (go_router) vers le détail concerné. Gère FCM en
foreground / background / app fermée.

### Section 5 — Compte

**16 · Paramètres** — `route /settings` · `POST /logout` · `DELETE /device`
En-tête profil (avatar initiales, nom, rôle, version). **Préférences** : Langue (FR/AR/EN, RTL
auto), Thème (Clair/Sombre/Système), toggle Notifications push. **Synchronisation** : état (nb
opérations en attente, dernière sync) + **Forcer la synchronisation**. Bouton **Se déconnecter**
(rouge, contour) → révoque token + désenregistre device FCM.

---

## 4 — ARCHITECTURE OFFLINE-FIRST (transversal)

```
- Toute requête de lecture passe par un cache Hive : afficher le cache d'abord, rafraîchir ensuite.
- Toute action terrain (scan livré/échec, accept/refuse pickup, COD) est écrite dans une
  FILE D'OPÉRATIONS Hive avec un id local, puis l'UI est mise à jour de façon OPTIMISTE.
- Un SyncService écoute connectivity_plus : au retour du réseau, il rejoue la file dans l'ordre,
  gère l'idempotence (clé locale) et les conflits (dernier état serveur fait foi).
- Le compteur « N opérations en attente de synchro » (header Dashboard + écran Paramètres) lit la
  taille de la file. Le bandeau orange MbOfflineBanner s'affiche dès que le réseau est coupé.
- Les scans batch (Pickup Rapide) sont regroupés en un seul POST au moment de « Envoyer ».
```

---

## 5 — i18n, RTL & ACCESSIBILITÉ (transversal)

```
- Français = locale par défaut. Fournir ar.arb (RTL automatique via Directionality) et en.arb.
- Aucune chaîne en dur : tout passe par AppLocalizations / .arb.
- Cibles tactiles ≥ 48 dp ; respect de textScaleFactor ; contrastes AA.
- Mode sombre suivant le système (déjà défini dans le thème §1.4).
- Retours haptiques + sonores sur chaque scan réussi (HapticFeedback + son court).
- Grandes polices par défaut pour lecture rapide en extérieur.
```

---

### Récapitulatif des routes (go_router)

```
/                       Splash
/login                  Login
/dashboard              Dashboard
/runsheets              Liste Runsheets
/runsheets/new          Création Runsheet
/runsheets/:id          Détail Runsheet
/runsheets/:id/map      Maps / Itinéraire
/shipments/:id          Détail Colis
/scan/delivery          Scan Livraison (+ sheets 07a/07b/07c)
/pickups                Liste Pickup
/pickups/:id            Détail Manifest
/scan/batch             Scan Pickup Rapide
/calls                  Historique appels
/stats                  Statistiques
/notifications          Notifications   (cible des deeplinks FCM)
/settings               Paramètres
```

> **Rappel identité MegaBoss :** header bleu navy #004E95 + logo blanc partout · rouge #EE0101
> réservé aux actions primaires · système de statut vert/rouge/bleu/orange constant · mono pour
> les identifiants. Ne pas introduire d'autres couleurs.

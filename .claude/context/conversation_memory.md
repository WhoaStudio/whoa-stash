# Conversation memory

<!-- Durable, team-shared knowledge that came out of working sessions: decisions and their
     reasons, things that were tried and failed, conventions agreed in review. One line per
     entry, newest last. Claude reads this on demand; keep it short enough to skim.
     Claude Code's auto memory is per-user and local; this file is the shared counterpart. -->

## Decisions

- _Decision — why — where it applies._
- 2026-10-28: fonds des panneaux en `NSGlassEffectView` (`GlassBackdrop`, masqué par la silhouette animée) au lieu d'un fond plein — demande explicite de passer au Liquid Glass ; l'encoche reste en noir plein tant qu'elle est repliée ; le disque du cadran de volume reste plein (il vit dans un calque animé, pas une vue).
- 2026-10-28: onglet AI de l'encoche refait en bloc vertical (en-tête, carte, filtres, activité) — le panneau ne grandit que sur AI (`NotchPanelGeometry.panelRect(in:tab:)`), la fenêtre garde le cadre le plus haut ; filtres, métriques d'activité et « resets available » restent en TODO faute de source.
- 2026-10-28: onglet Mirror (caméra) ajouté à l'encoche — la session ne tourne que panneau déplié + onglet choisi ; la luminosité du curseur n'agit que par deux voiles sur l'aperçu, jamais sur l'écran ; même hauteur que Calendar.
- 2026-10-28: Liquid Glass (`NSGlassEffectView`) retiré de toute l'app, travail gardé dans `git stash` (`liquid-glass`) — à reprendre plus tard ; fonds pleins conservés en attendant.
- 2026-10-28: zone AirDrop dans le bac — le panneau reste l'unique cible de dépôt ; moitié gauche = garder, droite = AirDrop, y compris pour un glisser venu d'une vignette (la copie laisse le fichier dans le bac, seul `.move` hors de l'app l'en retire) ; le panneau reste sous l'image glissée pendant un glisser sortant.
- 2026-10-28: engrenage des Préférences sorti de la capsule d'onglets, posé en haut à droite du panneau ; `topClearance` porté de 4 à 14 pour plus d'air sous l'encoche.
- 2026-10-28: réglage `notchPanel.notchlessStyle` (défaut `island`) — seul l'état replié flotte (6 pt sous le bord) sur un écran sans encoche ; le panneau déplié reste suspendu au bord ; un écran à encoche ignore le réglage.
- 2026-10-28: « Now Playing » via `mediaremote-adapter` (perl titré, seule voie MediaRemote depuis macOS 15.4), livré comme `MediaRemoteAdapter.bin` + script en ressources, lien `*.framework` recréé dans les caches à l'exécution — le groupe synchronisé d'Xcode ne copie ni un `.framework` ni un `.dylib` en ressource. Visualiseur simulé ; titre/artiste/commandes dans l'onglet Global déplié.
- 2026-10-28: onglet Global = semaine en haut + lecteur dessous (172 pt suffisent : 46 + 8 + 112) ; le lecteur reste au repos (« Nothing playing », dernier morceau en pause) ; seules les ailes de l'encoche se masquent 5 s après l'arrêt. Ailes de lecture 60 pt, +2 pt de hauteur repliée, pastille Bluetooth inchangée.
- 2026-10-28: détection de coups via l'accéléromètre SPU (`AppleSPUHIDDevice`, page 0xFF00 usage 3) à la place des taps de bord du trackpad — lecture sans root à condition de réveiller le *pilote* `AppleSPUHIDDriver` (pas le device) ; `KnockClassifier` pur à horloge injectée ; seuil par défaut ≈ 0,08 g (sensibilité 0,7) d'après un enregistrement réel (coups fermes 0,09–0,19 g, légers 0,035–0,065 g, clavier/clics < 0,03 g) ; défaut = coup simple éteint l'écran.
- 2026-10-28: pas d'option gauche/droite pour les coups — sur l'enregistrement, tous les pics sont dominés par z (vertical) avec le même signe des deux côtés, le rapport x/z se recoupe et l'amplitude varie avec la force du coup ; le gyroscope n'a pas été enregistré.
- 2026-10-28: « Playing Next » à droite du lecteur, seulement pour Apple Musique (AppleScript via `osascript`, vide en lecture aléatoire) et Spotify (API web `me/player/queue`, PKCE + redirection loopback 127.0.0.1:48731, identifiant client collé dans Préférences, jetons au trousseau) — MediaRemote ne donne pas la file ; navigateurs sans file.
- 2026-10-28: engrenage des Préférences aligné par son glyphe sur le bord droit du contenu de tous les onglets (au lieu d'être centré sur la dernière colonne de la semaine, qui défile).

## Tried and rejected

- _Approach — why it didn't work._

## Lessons

- _Thing that bit us — how to avoid it._
- 2026-10-28: onglet Clipboard dans l'encoche — sondage de `changeCount` toutes les 0,5 s, 50 éléments gardés dans `Application Support/whoa-stash/Clipboard/` (JSON + PNG, pas `UserDefaults`), contenus `ConcealedType`/`TransientType` ignorés ; un fichier quelconque n'a pas de filtre propre (visible sous « All Clips » seulement), vidéo en orange.
- 2026-10-28: jeton Claude lu via `/usr/bin/security find-generic-password -w` et non `SecItemCopyMatching` — Claude Code réécrit l'item avec `add-generic-password -U` à chaque rafraîchissement, ce qui ramène la liste de partitions à `apple-tool:` et efface le `teamid:` de « Toujours autoriser » ; une lecture directe redemandait donc le mot de passe à presque chaque lancement.
- 2026-10-29: balayage d'onglets de l'encoche (trackpad à deux doigts et glisser souris) via `TabSwipeTracker` ; l'onglet suit le doigt puis change au relâché au-delà de 60 pt, sans rebouclage ; les vues qui défilent (semaine, presse-papiers) gardent leurs événements, la molette de souris est ignorée. Pas de réordonnancement des onglets.

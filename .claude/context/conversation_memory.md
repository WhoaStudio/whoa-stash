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
- 2026-10-28: taps de bord du trackpad via `MultitouchSupport` chargé par `dlopen` (frames lues à des décalages fixes de `MTTouch`, 96 octets), classés par `EdgeTapClassifier` (pur, horloge injectée) ; défaut = tap simple à droite éteint l'écran ; le tap simple n'attend un double tap que sur les côtés dont le double a une action ; un callback `@convention(c)` capturant `self` fait planter le compilateur (SendNonSendable), d'où le callback statique.

## Tried and rejected

- _Approach — why it didn't work._

## Lessons

- _Thing that bit us — how to avoid it._
- 2026-10-28: onglet Clipboard dans l'encoche — sondage de `changeCount` toutes les 0,5 s, 50 éléments gardés dans `Application Support/whoa-stash/Clipboard/` (JSON + PNG, pas `UserDefaults`), contenus `ConcealedType`/`TransientType` ignorés ; un fichier quelconque n'a pas de filtre propre (visible sous « All Clips » seulement), vidéo en orange.

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

## Tried and rejected

- _Approach — why it didn't work._

## Lessons

- _Thing that bit us — how to avoid it._

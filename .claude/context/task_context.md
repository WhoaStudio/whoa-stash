# Task context

## Goal

Taps de bord du trackpad (gauche/droite × simple/double) avec une action réglable dans Préférences > Trackpad. Défaut : tap simple à droite = écran éteint.

## Status

- Implémenté : `Features/TrackpadGestures/`, `Core/Settings/TrackpadGestureSettings.swift`, volet `TrackpadSettingsViewController`. Build OK, 131 tests OK (`EdgeTapClassifierTests`, `TrackpadSettingsStorageTests`). Rien de commité.
- Pas vérifié sur matériel : décalages de `MTTouch` (id 16, x 32, y 36, taille 48), seuil de taille de paume (`maxSize = 2.0`), tap-to-click qui clique aussi sous le curseur. `--edge-tap=right-single` simule sans trackpad.

## Open questions

- Seuils (durée 0,25 s, mouvement 0,03, zone 0,2) à ajuster à l'usage.

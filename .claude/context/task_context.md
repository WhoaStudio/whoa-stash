# Task context

## Goal

Détection de coups sur le châssis (accéléromètre SPU) : coup simple = écran éteint par défaut, double coup réglable, volet Préférences > Knock.

## Status

- Implémenté : `Features/Knock/`, `Core/Settings/KnockSettings.swift`, volet `KnockSettingsViewController`. Build OK, 135 tests OK (`KnockClassifierTests` sur échantillons simulés et sur extraits réels de `KnockRecordings`, `KnockSettingsStorageTests`). Rien de commité.
- Pas vérifié en conditions réelles : l'app complète avec le capteur (lancer sans `--knock=` éteint l'écran au premier coup), faux déclenchements en usage normal (bureau qui bouge, haut-parleurs).
- Gauche/droite : non exposé, voir `conversation_memory.md`.

## Open questions

- Gyroscope (autre device SPU) non enregistré pour le gauche/droite.

# Task context

## Goal

Réglage de forme du panneau de l'encoche sur les écrans sans encoche : « Notch » (silhouette suspendue au bord du haut, comportement actuel) ou « Island » (pastille flottante façon Dynamic Island). Les écrans à encoche gardent l'encoche matérielle. Décidé par écran.

## Status

- Exploré : `NotchPanelGeometry` (notchRect via `safeAreaInsets`, collapsedSize, hotZone, windowFrame), `NotchPanelContentView` (collapsed/winged/expanded paths via `PanelGeometry.silhouette`), `NotchPanelController.rebuildWindows` (une fenêtre par écran, `place(on:)`), `AppSettings.NotchPanelSettings` + décodage tolérant, carte « Notch Panel » de `GeneralSettingsViewController`.
- Plan proposé dans le chat ; en attente de réponses. Aucun code modifié.

## Open questions

- Défaut sur écran sans encoche : notch ou island ?
- En mode island, le panneau déplié reste-t-il suspendu au bord (seul le repli flotte) ?
- La capture fournie montre déjà une pastille flottante, alors que le code suspend la silhouette au bord du haut.

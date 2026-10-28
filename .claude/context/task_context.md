# Task context

## Goal

Vue « Now Playing » persistante dans l'encoche (YouTube navigateur, Spotify, Apple Music) : pochette, visualiseur animé, lecture/pause, suivant/précédent. Mêmes ailes que la pastille Bluetooth, mais tenues tant que ça joue.

## Status

- Implémenté, build OK, 8 tests OK (`NowPlayingParserTests`, `NowPlayingViewModelTests`). Rien de commité.
- Source : `mediaremote-adapter` via `/usr/bin/perl` ; script + `MediaRemoteAdapter.bin` dans `whoa-stash/Resources/MediaRemoteAdapter/`, sources et `build.sh` dans `Vendor/MediaRemoteAdapter/`.
- Vérifié : `get` lit bien le navigateur sur cette machine ; l'app lance le flux perl depuis le bundle.
- Pas vérifié : rendu visuel des ailes et de la ligne Global, commandes sur YouTube/Spotify/Musique. Une instance Xcode (debugserver) tient l'encoche ; à arrêter avant de tester (`--now-playing=playing|paused` pour le mock).

## Open questions

- Visualiseur simulé (gaté sur `playing`) : un vrai niveau audio demanderait un tap Core Audio + permission.

import QuartzCore

/// Deux profils de ressort réutilisés par tout l'overlay, pour que chaque micro-interaction
/// (apparition du widget, allumage d'une graduation, crossfade du bouton) partage la même
/// signature de mouvement plutôt que des durées ad hoc.
enum SpringPreset {
    /// Mouvements d'ensemble (apparition/disparition du widget) : ample et posé.
    case gentle
    /// Changements d'état ponctuels (graduation, glow, bouton) : vif mais toujours amorti.
    case snappy

    fileprivate func makeAnimation(keyPath: String) -> CASpringAnimation {
        let animation = CASpringAnimation(keyPath: keyPath)
        switch self {
        case .gentle:
            animation.damping = 20
            animation.stiffness = 140
            animation.mass = 1.1
        case .snappy:
            animation.damping = 18
            animation.stiffness = 260
            animation.mass = 0.9
        }
        animation.initialVelocity = 0
        animation.duration = animation.settlingDuration
        return animation
    }
}

extension CALayer {
    /// Anime `keyPath` vers `value` avec un `CASpringAnimation`, et met à jour la valeur du
    /// modèle en parallèle pour que le calque reste dans le bon état une fois l'animation retirée.
    func springAnimate(keyPath: String, to newValue: Any, preset: SpringPreset = .snappy, completion: (() -> Void)? = nil) {
        CATransaction.begin()
        if let completion {
            CATransaction.setCompletionBlock(completion)
        }

        let animation = preset.makeAnimation(keyPath: keyPath)
        animation.fromValue = presentation()?.value(forKeyPath: keyPath) ?? self.value(forKeyPath: keyPath)
        animation.toValue = newValue

        setValue(newValue, forKeyPath: keyPath)
        add(animation, forKey: keyPath)

        CATransaction.commit()
    }
}

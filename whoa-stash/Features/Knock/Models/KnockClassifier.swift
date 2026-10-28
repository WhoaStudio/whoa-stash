import Foundation

/// Un échantillon de l'accéléromètre, en g, avec la date de lecture (secondes, horloge monotone).
nonisolated struct AccelSample: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double
    var time: TimeInterval
}

nonisolated struct Knock: Equatable, Sendable {
    /// 1 pour un coup simple, 2 pour un double coup.
    var count: Int
}

/// Transforme le flux de l'accéléromètre en coups. Pur : le temps vient des échantillons, sans
/// minuteur interne, donc testable sur des échantillons enregistrés ou simulés.
///
/// La gravité est retirée par une moyenne glissante lente ; un coup est un pic de l'accélération
/// restante au-dessus de `threshold`. Un pic suivi de près d'une frappe ou d'un clic
/// (`recentInput`) est ignoré. Un second coup dans `groupingWindow` fait un double coup et
/// annule le coup simple en attente.
nonisolated struct KnockClassifier {

    var threshold: Double = 0.1
    /// Constante de temps du filtre de gravité.
    var gravityTimeConstant: TimeInterval = 0.5
    /// Un coup résonne : on attend ce délai pour laisser le pic se former avant de juger.
    var peakWindow: TimeInterval = 0.03
    /// Délai mort après un pic, pour ne pas compter les rebonds d'un même coup.
    var cooldown: TimeInterval = 0.12
    var groupingWindow: TimeInterval = 0.45
    /// Après le premier échantillon, le filtre de gravité n'est pas encore fiable : pas de jugement.
    var warmup: TimeInterval = 0.3
    var hasDoubleAction = false

    /// Seuil (en g) pour une sensibilité de 0 (dur) à 1 (léger). Sur l'enregistrement de référence,
    /// les coups fermes font 0,09 à 0,19 g et les coups légers 0,035 à 0,065 g ; la saisie au clavier
    /// et les clics ne dépassent pas 0,03 g.
    static func threshold(forSensitivity sensitivity: Double) -> Double {
        let s = min(max(sensitivity, 0), 1)
        return 0.4 * pow(0.1, s)  // 0,4 g → 0,04 g
    }

    private var gravity: (x: Double, y: Double, z: Double)?
    private var lastTime: TimeInterval?
    private var warmupEnd: TimeInterval?
    private var burstStart: TimeInterval?
    private var lastBurstStart: TimeInterval = -.infinity
    private var pending: TimeInterval?

    /// Date à laquelle le coup simple en attente doit partir, s'il y en a un.
    var pendingDeadline: TimeInterval? { pending.map { $0 + groupingWindow } }

    mutating func ingest(_ sample: AccelSample, recentInput: () -> Bool) -> [Knock] {
        var emitted = flushExpired(at: sample.time)

        guard var g = gravity, let previous = lastTime else {
            gravity = (sample.x, sample.y, sample.z)
            lastTime = sample.time
            warmupEnd = sample.time + warmup
            return emitted
        }
        let alpha = min(1, max(0, (sample.time - previous) / gravityTimeConstant))
        g.x += alpha * (sample.x - g.x)
        g.y += alpha * (sample.y - g.y)
        g.z += alpha * (sample.z - g.z)
        gravity = g
        lastTime = sample.time

        // Le temps que le filtre trouve la gravité, tout ressemblerait à un coup.
        if let warmupEnd, sample.time < warmupEnd { return emitted }

        let dx = sample.x - g.x, dy = sample.y - g.y, dz = sample.z - g.z
        let magnitude = (dx * dx + dy * dy + dz * dz).squareRoot()

        if let start = burstStart {
            if sample.time - start >= peakWindow {
                burstStart = nil
                if !recentInput() { emitted += register(at: start) }
            }
        } else if magnitude > threshold, sample.time - lastBurstStart >= cooldown {
            burstStart = sample.time
            lastBurstStart = sample.time
        }
        return emitted
    }

    /// Fait avancer l'horloge sans échantillon : libère le coup simple dont le délai est écoulé.
    mutating func advance(to time: TimeInterval) -> [Knock] {
        flushExpired(at: time)
    }

    private mutating func flushExpired(at time: TimeInterval) -> [Knock] {
        guard let waiting = pending, time - waiting > groupingWindow else { return [] }
        pending = nil
        return [Knock(count: 1)]
    }

    private mutating func register(at time: TimeInterval) -> [Knock] {
        if let waiting = pending, time - waiting <= groupingWindow {
            pending = nil
            return [Knock(count: 2)]
        }
        if hasDoubleAction {
            pending = time
            return []
        }
        return [Knock(count: 1)]
    }
}

/// Signal synthétique d'un coup : utilisé par `MockKnockSensor` et par les tests.
nonisolated enum KnockSignal {
    /// Gravité seule (0, 0, -1) à `rate` Hz pendant `duration` s, avec une oscillation amortie
    /// d'amplitude `amplitude` (g) à chaque date de `knocksAt`.
    static func samples(knocksAt: [TimeInterval], amplitude: Double = 0.5, duration: TimeInterval,
                        rate: Double = 800, start: TimeInterval = 0) -> [AccelSample] {
        (0..<Int(duration * rate)).map { index in
            let t = Double(index) / rate
            var bump = 0.0
            for knock in knocksAt where t >= knock {
                let dt = t - knock
                bump += amplitude * exp(-dt / 0.01) * sin(2 * .pi * 150 * dt)
            }
            return AccelSample(x: 0, y: 0, z: -1 + bump, time: start + t)
        }
    }
}

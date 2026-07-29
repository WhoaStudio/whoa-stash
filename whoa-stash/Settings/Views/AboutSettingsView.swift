import AppKit

/// Écran "About" : icône, nom, version, copyright, liens GitHub et site — une mise en page
/// centrée, pas une carte de formulaire.
final class AboutSettingsView: NSViewController {

    private let animationsEnabled: () -> Bool

    private static let githubURL = URL(string: "https://github.com/WhoaStudio/whoa-stash")!
    private static let websiteURL = URL(string: "https://whoastudio.dev")!

    init(animationsEnabled: @escaping () -> Bool) {
        self.animationsEnabled = animationsEnabled
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: SettingsMetrics.windowSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let iconView = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 20
        iconView.layer?.cornerCurve = .continuous
        iconView.layer?.masksToBounds = true

        let nameLabel = NSTextField(labelWithString: "whoa-stash")
        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: "Version \(Self.versionString)")
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let copyrightLabel = NSTextField(labelWithString: "© 2026 Ugolin Ollé")
        copyrightLabel.font = .systemFont(ofSize: 11)
        copyrightLabel.textColor = .tertiaryLabelColor
        copyrightLabel.alignment = .center

        let githubButton = NSButton(title: "GitHub", target: self, action: #selector(openGitHub))
        githubButton.bezelStyle = .rounded
        githubButton.controlSize = .regular

        let websiteButton = NSButton(title: "Website", target: self, action: #selector(openWebsite))
        websiteButton.bezelStyle = .rounded
        websiteButton.controlSize = .regular

        let buttonsStack = NSStackView(views: [githubButton, websiteButton])
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = 12

        let stack = NSStackView(views: [iconView, nameLabel, versionLabel, copyrightLabel, buttonsStack])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(20, after: iconView)
        stack.setCustomSpacing(24, after: copyrightLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 88),
            iconView.heightAnchor.constraint(equalToConstant: 88),

            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard animationsEnabled(), let layer = view.layer else { return }
        layer.opacity = 0
        layer.transform = CATransform3DMakeTranslation(0, 8, 0)
        layer.springAnimate(keyPath: "opacity", to: 1, preset: .gentle)
        layer.springAnimate(keyPath: "transform", to: NSValue(caTransform3D: CATransform3DIdentity), preset: .gentle)
    }

    private static var versionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(Self.githubURL)
    }

    @objc private func openWebsite() {
        NSWorkspace.shared.open(Self.websiteURL)
    }
}

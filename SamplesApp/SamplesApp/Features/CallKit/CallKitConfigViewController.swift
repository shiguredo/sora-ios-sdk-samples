import UIKit

/// CallKit サンプルの発信画面です。
///
/// 通話自体の UI は CallKit のシステム通話 UI が表示します。この画面は発信先の
/// チャネル ID の入力と、通話状態の確認に使います。
final class CallKitConfigViewController: UIViewController {
  private let callManager = CallKitCallManager.shared

  private let descriptionLabel = UILabel()
  private let channelIdTitleLabel = UILabel()
  private let channelIdTextField = UITextField()
  private let statusLabel = UILabel()
  private let activityIndicator = UIActivityIndicatorView(style: .medium)
  private let startButton = UIButton(type: .system)
  private let endButton = UIButton(type: .system)
  private var lastStatusMessage: String?

  override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = "CallKit Sample"

    configureViews()

    channelIdTextField.text = CallKitEnvironment.channelId
    render()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    callManager.onStateChanged = { [weak self] state, message in
      self?.render(state: state, message: message)
    }
    render()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    callManager.onStateChanged = nil
    // サンプル画面を閉じたまま通話が残らないように、画面を離れるときに終了する。
    callManager.endCallIfNeeded()
  }

  private func configureViews() {
    descriptionLabel.text =
      "CallKit のシステム通話 UI から Sora に音声で発信します。着信には対応していません。"
      + "通話中にこの画面を閉じると通話は終了します。"
      + "受話口で通話中にサイドボタンを押すと通話が終了する場合があります。"
      + "スピーカーまたはヘッドセットを使用してください。"
    descriptionLabel.numberOfLines = 0
    descriptionLabel.font = .preferredFont(forTextStyle: .body)
    descriptionLabel.adjustsFontForContentSizeCategory = true
    descriptionLabel.textColor = .secondaryLabel

    channelIdTitleLabel.text = "チャネル ID"
    channelIdTitleLabel.font = .preferredFont(forTextStyle: .headline)
    channelIdTitleLabel.adjustsFontForContentSizeCategory = true
    channelIdTitleLabel.isAccessibilityElement = false

    channelIdTextField.borderStyle = .roundedRect
    channelIdTextField.autocapitalizationType = .none
    channelIdTextField.autocorrectionType = .no
    channelIdTextField.spellCheckingType = .no
    channelIdTextField.clearButtonMode = .whileEditing
    channelIdTextField.returnKeyType = .done
    channelIdTextField.placeholder = "channel_id"
    channelIdTextField.font = .preferredFont(forTextStyle: .body)
    channelIdTextField.adjustsFontForContentSizeCategory = true
    channelIdTextField.accessibilityLabel = "チャネル ID"
    channelIdTextField.delegate = self
    channelIdTextField.addTarget(
      self,
      action: #selector(channelIdDidChange),
      for: .editingChanged)

    statusLabel.numberOfLines = 0
    statusLabel.font = .preferredFont(forTextStyle: .callout)
    statusLabel.adjustsFontForContentSizeCategory = true
    statusLabel.textColor = .secondaryLabel

    activityIndicator.hidesWhenStopped = true
    activityIndicator.isAccessibilityElement = false

    var startButtonConfiguration = UIButton.Configuration.filled()
    startButtonConfiguration.title = "発信"
    startButtonConfiguration.cornerStyle = .large
    startButtonConfiguration.titleTextAttributesTransformer =
      UIConfigurationTextAttributesTransformer { incoming in
        var outgoing = incoming
        outgoing.font = .preferredFont(forTextStyle: .body)
        return outgoing
      }
    startButton.configuration = startButtonConfiguration
    startButton.titleLabel?.adjustsFontForContentSizeCategory = true
    startButton.addTarget(self, action: #selector(didTapStartCall), for: .touchUpInside)

    var endButtonConfiguration = UIButton.Configuration.gray()
    endButtonConfiguration.title = "通話を終了"
    endButtonConfiguration.baseForegroundColor = .systemRed
    endButtonConfiguration.cornerStyle = .large
    endButtonConfiguration.titleTextAttributesTransformer =
      UIConfigurationTextAttributesTransformer { incoming in
        var outgoing = incoming
        outgoing.font = .preferredFont(forTextStyle: .body)
        return outgoing
      }
    endButton.configuration = endButtonConfiguration
    endButton.titleLabel?.adjustsFontForContentSizeCategory = true
    endButton.addTarget(self, action: #selector(didTapEndCall), for: .touchUpInside)

    let statusStack = UIStackView(arrangedSubviews: [activityIndicator, statusLabel])
    statusStack.axis = .horizontal
    statusStack.alignment = .center
    statusStack.spacing = 8

    let stackView = UIStackView(arrangedSubviews: [
      descriptionLabel,
      channelIdTitleLabel,
      channelIdTextField,
      statusStack,
      startButton,
      endButton,
    ])
    stackView.axis = .vertical
    stackView.spacing = 16
    stackView.setCustomSpacing(24, after: descriptionLabel)
    stackView.setCustomSpacing(8, after: channelIdTitleLabel)
    let scrollView = UIScrollView()
    scrollView.alwaysBounceVertical = true
    scrollView.keyboardDismissMode = .interactive
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)
    scrollView.addSubview(stackView)

    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
      stackView.topAnchor.constraint(
        equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
      stackView.leadingAnchor.constraint(
        equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
      stackView.trailingAnchor.constraint(
        equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
      stackView.bottomAnchor.constraint(
        equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
      stackView.widthAnchor.constraint(
        equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
      startButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
      endButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
    ])
  }

  private func render(
    state: CallKitCallManager.CallState? = nil,
    message: String? = nil
  ) {
    let state = state ?? callManager.state
    let message = message ?? callManager.statusMessage
    statusLabel.text = message

    channelIdTextField.isEnabled = callManager.canStartCall
    updateStartButton()
    endButton.isEnabled = callManager.canEndCall

    switch state {
    case .requesting, .connecting:
      activityIndicator.startAnimating()
      statusLabel.textColor = .secondaryLabel
    case .connected:
      activityIndicator.stopAnimating()
      statusLabel.textColor = .label
    case .idle:
      activityIndicator.stopAnimating()
      statusLabel.textColor = .secondaryLabel
    }

    if lastStatusMessage != message {
      lastStatusMessage = message
      if view.window != nil {
        UIAccessibility.post(notification: .announcement, argument: message)
      }
    }
  }

  /// チャネル ID と通話状態から発信ボタンの有効状態を更新します。
  private func updateStartButton() {
    let channelId =
      channelIdTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    startButton.isEnabled = callManager.canStartCall && !channelId.isEmpty
  }

  @objc private func channelIdDidChange() {
    updateStartButton()
  }

  @objc private func didTapStartCall() {
    view.endEditing(true)

    guard
      let channelId = channelIdTextField.text?.trimmingCharacters(
        in: .whitespacesAndNewlines),
      !channelId.isEmpty
    else {
      presentAlert(title: "チャネル ID を入力してください")
      return
    }

    callManager.startCall(channelId: channelId)
  }

  @objc private func didTapEndCall() {
    callManager.endCall()
  }

  private func presentAlert(title: String, message: String? = nil) {
    let alertController = UIAlertController(
      title: title,
      message: message,
      preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
    present(alertController, animated: true)
  }
}

// MARK: - UITextFieldDelegate

extension CallKitConfigViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}

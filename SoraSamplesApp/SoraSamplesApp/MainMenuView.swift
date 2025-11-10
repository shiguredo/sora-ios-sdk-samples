import SwiftUI
import UIKit

private struct SampleItem: Identifiable, Equatable {
  let id = UUID()
  let title: String
  let subtitle: String
  let storyboardName: String
}

struct MainMenuView: View {
  @State private var selectedSample: SampleItem?

  private let samples: [SampleItem] = [
    SampleItem(
      title: "DataChannel Sample",
      subtitle: "DataChannel を使ったメッセージング",
      storyboardName: "DataChannel"
    ),
    SampleItem(
      title: "Deco Streaming Sample",
      subtitle: "エフェクト付き映像配信",
      storyboardName: "DecoStreaming"
    ),
    SampleItem(
      title: "Screen Cast Sample",
      subtitle: "画面共有",
      storyboardName: "ScreenCast"
    ),
    SampleItem(
      title: "Simulcast Sample",
      subtitle: "サイマルキャスト配信",
      storyboardName: "Simulcast"
    ),
    SampleItem(
      title: "Spotlight Sample",
      subtitle: "スポットライト視聴",
      storyboardName: "Spotlight"
    )
  ]

  var body: some View {
    navigationContainer
      .fullScreenCover(item: $selectedSample) { sample in
        SampleHost(sample: sample) {
          selectedSample = nil
        }
      }
  }

  @ViewBuilder
  private var navigationContainer: some View {
    if #available(iOS 16.0, *) {
      NavigationStack {
        sampleList
      }
    } else {
      NavigationView {
        sampleList
      }
      .navigationViewStyle(StackNavigationViewStyle())
    }
  }

  private var sampleList: some View {
    List(samples) { sample in
      Button {
        selectedSample = sample
      } label: {
        VStack(alignment: .leading, spacing: 4) {
          Text(sample.title)
            .font(.headline)
          Text(sample.subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
    }
    .navigationTitle("Sora Samples")
  }
}

private struct SampleHost: UIViewControllerRepresentable {
  final class Coordinator: NSObject {
    let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
      self.onDismiss = onDismiss
    }

    @objc func handleCloseButtonTapped() {
      onDismiss()
    }

    func installCloseButtonIfNeeded(on navigationController: UINavigationController) {
      guard let root = navigationController.viewControllers.first else {
        return
      }

      let closeItem = UIBarButtonItem(
        barButtonSystemItem: .close,
        target: self,
        action: #selector(handleCloseButtonTapped)
      )

      if root.navigationItem.leftBarButtonItem == nil {
        root.navigationItem.leftBarButtonItem = closeItem
      } else {
        root.navigationItem.rightBarButtonItem = closeItem
      }
    }
  }

  let sample: SampleItem
  let onDismiss: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onDismiss: onDismiss)
  }

  func makeUIViewController(context: Context) -> UIViewController {
    let storyboard = UIStoryboard(name: sample.storyboardName, bundle: .main)

    guard let initialViewController = storyboard.instantiateInitialViewController() else {
      return errorViewController()
    }

    let navigationController: UINavigationController
    if let existingNavigationController = initialViewController as? UINavigationController {
      navigationController = existingNavigationController
    } else {
      navigationController = UINavigationController(rootViewController: initialViewController)
    }

    navigationController.modalPresentationStyle = .fullScreen
    context.coordinator.installCloseButtonIfNeeded(on: navigationController)
    return navigationController
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

  private func errorViewController() -> UIViewController {
    let label = UILabel()
    label.text = "\(sample.storyboardName) を読み込めませんでした"
    label.textAlignment = .center
    label.numberOfLines = 0

    let controller = UIViewController()
    controller.view.backgroundColor = .systemBackground
    controller.view.addSubview(label)

    label.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: controller.view.leadingAnchor, constant: 20),
      label.trailingAnchor.constraint(lessThanOrEqualTo: controller.view.trailingAnchor, constant: -20)
    ])

    return controller
  }
}

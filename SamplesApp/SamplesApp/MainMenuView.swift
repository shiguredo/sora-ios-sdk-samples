import SwiftUI
import UIKit

private struct SampleItem: Identifiable {
  enum Destination {
    case storyboard(name: String)
    case swiftUIView(() -> AnyView)
  }

  let id = UUID()
  let title: String
  let subtitle: String
  let destination: Destination
}

struct MainMenuView: View {
  @State private var selectedSample: SampleItem?

  private let samples: [SampleItem] = [
    SampleItem(
      title: "Video Chat Sample",
      subtitle: "ビデオチャット",
      destination: .storyboard(name: "VideoChat")
    ),
    SampleItem(
      title: "SwiftUI Video Chat Sample",
      subtitle: "SwiftUI + SwiftUIVideoView のビデオチャット",
      destination: .swiftUIView { AnyView(SwiftUIVideoChatSampleView()) }
    ),
    SampleItem(
      title: "DataChannel Sample",
      subtitle: "DataChannel を使ったメッセージング",
      destination: .storyboard(name: "DataChannel")
    ),
    SampleItem(
      title: "Deco Streaming Sample",
      subtitle: "エフェクト付き映像配信",
      destination: .storyboard(name: "DecoStreaming")
    ),
    SampleItem(
      title: "Screen Cast Sample",
      subtitle: "画面共有",
      destination: .storyboard(name: "ScreenCast")
    ),
    SampleItem(
      title: "Simulcast Sample",
      subtitle: "サイマルキャスト配信",
      destination: .storyboard(name: "Simulcast")
    ),
    SampleItem(
      title: "Spotlight Sample",
      subtitle: "スポットライト視聴",
      destination: .storyboard(name: "Spotlight")
    ),
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
    switch sample.destination {
    case .storyboard(let name):
      return makeStoryboardViewController(
        named: name,
        coordinator: context.coordinator
      )
    case .swiftUIView(let builder):
      return makeSwiftUIViewController(builder: builder, coordinator: context.coordinator)
    }
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

  private func makeStoryboardViewController(
    named name: String,
    coordinator: Coordinator
  ) -> UIViewController {
    let storyboard = UIStoryboard(name: name, bundle: .main)

    guard let initialViewController = storyboard.instantiateInitialViewController() else {
      return errorViewController(name: name)
    }

    let navigationController: UINavigationController
    if let existingNavigationController = initialViewController as? UINavigationController {
      navigationController = existingNavigationController
    } else {
      navigationController = UINavigationController(rootViewController: initialViewController)
    }

    navigationController.modalPresentationStyle = .fullScreen
    coordinator.installCloseButtonIfNeeded(on: navigationController)
    return navigationController
  }

  private func makeSwiftUIViewController(
    builder: () -> AnyView,
    coordinator: Coordinator
  ) -> UIViewController {
    let hostingController = UIHostingController(rootView: builder())
    let navigationController = UINavigationController(rootViewController: hostingController)
    navigationController.modalPresentationStyle = .fullScreen
    coordinator.installCloseButtonIfNeeded(on: navigationController)
    return navigationController
  }

  private func errorViewController(name: String) -> UIViewController {
    let label = UILabel()
    label.text = "\(name) を読み込めませんでした"
    label.textAlignment = .center
    label.numberOfLines = 0

    let controller = UIViewController()
    controller.view.backgroundColor = .systemBackground
    controller.view.addSubview(label)

    label.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
      label.leadingAnchor.constraint(
        greaterThanOrEqualTo: controller.view.leadingAnchor, constant: 20),
      label.trailingAnchor.constraint(
        lessThanOrEqualTo: controller.view.trailingAnchor, constant: -20),
    ])

    return controller
  }
}

import SwiftUI
import UIKit

// UIKitでnameとisEnabledを管理し、UILabelでテキストを表示
class UIKitView: UIView {
    private let label: UILabel
    var isEnabled: Bool = false {
        didSet {
            updateText()
        }
    }
    
    override init(frame: CGRect) {
        label = UILabel(frame: .zero)
        super.init(frame: frame)
        setupView()
        updateText()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: self.centerYAnchor),
        ])
    }

    // isEnabledの値に応じて表示されるテキストを変更
    private func updateText() {
        label.text = isEnabled ? "zztkm" : "not zztkm"
    }
}

// UIViewRepresentableでUIKitViewをSwiftUIに統合
struct RepresentedUIKitView: UIViewRepresentable {
    @Binding var isEnabled: Bool

    func makeUIView(context: Context) -> UIKitView {
        let uiKitView = UIKitView()
        uiKitView.isEnabled = isEnabled
        return uiKitView
    }

    func updateUIView(_ uiView: UIKitView, context: Context) {
        uiView.isEnabled = isEnabled
    }
}

// MySubViewでRepresentedUIKitViewを描画
struct MySubView: View {
    @Binding var isEnabled: Bool

    var body: some View {
        RepresentedUIKitView(isEnabled: $isEnabled) // UIKitViewの表示
    }
}

// SandboxViewでToggleを制御し、MySubViewに変更を伝達
struct SandboxView: View {
    @State private var isEnabled = false

    var body: some View {
        VStack {
            Toggle("Enabled", isOn: $isEnabled) // ToggleでisEnabledを制御
            MySubView(isEnabled: $isEnabled) // MySubViewにisEnabledを渡す
        }
        .padding()
    }
}

// Preview
#Preview {
    SandboxView()
}

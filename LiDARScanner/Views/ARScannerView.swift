import SwiftUI
import RealityKit

struct ARScannerView: UIViewRepresentable {
    @ObservedObject var sessionManager: ARSessionManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        sessionManager.setupARView(arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

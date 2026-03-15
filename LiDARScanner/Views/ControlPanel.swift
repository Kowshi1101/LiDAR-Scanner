import SwiftUI

struct ControlPanel: View {
    @ObservedObject var sessionManager: ARSessionManager
    var onExport: () -> Void
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 24) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.15), in: Circle())
            }

            Button {
                if sessionManager.isScanning {
                    sessionManager.stopScanning()
                } else {
                    sessionManager.startScanning()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(sessionManager.isScanning ? Color.red : Color.green)
                        .frame(width: 70, height: 70)
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 76, height: 76)
                    Image(systemName: sessionManager.isScanning ? "stop.fill" : "record.circle")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }

            Button {
                onExport()
            } label: {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .disabled(sessionManager.isScanning || sessionManager.pointCount == 0)
            .opacity(sessionManager.isScanning || sessionManager.pointCount == 0 ? 0.4 : 1.0)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 30)
    }
}

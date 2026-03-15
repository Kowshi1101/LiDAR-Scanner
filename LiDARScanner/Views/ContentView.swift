import SwiftUI

struct ContentView: View {
    @StateObject private var sessionManager = ARSessionManager()
    @State private var showSettings = false
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            if sessionManager.isLiDARAvailable {
                scannerInterface
            } else {
                LiDARUnavailableView()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(sessionManager: sessionManager)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = sessionManager.exportedFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Scanner Interface

    private var scannerInterface: some View {
        ZStack {
            ARScannerView(sessionManager: sessionManager)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                statusBar
                Spacer()
                ControlPanel(
                    sessionManager: sessionManager,
                    onExport: exportPointCloud,
                    showSettings: $showSettings
                )
            }

            if sessionManager.isProcessing {
                processingOverlay
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            Label {
                Text("\(sessionManager.pointCount)")
                    .monospacedDigit()
            } icon: {
                Image(systemName: "circle.grid.3x3.fill")
            }

            Spacer()

            if sessionManager.isScanning {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("REC")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }

            Spacer()

            Label {
                Text(formatDuration(sessionManager.scanDuration))
                    .monospacedDigit()
            } icon: {
                Image(systemName: "timer")
            }
        }
        .font(.callout)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Processing Point Cloud...")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Filtering noise and exporting PLY")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Actions

    private func exportPointCloud() {
        Task {
            if let _ = await sessionManager.exportPointCloud() {
                showShareSheet = true
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views

struct LiDARUnavailableView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sensor.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("LiDAR Not Available")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("This device does not have a LiDAR sensor.\nPlease use iPhone 12 Pro or later.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

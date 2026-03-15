import SwiftUI

struct SettingsView: View {
    @ObservedObject var sessionManager: ARSessionManager
    @Environment(\.dismiss) private var dismiss

    private let confidenceLevels = ["Low (All)", "Medium", "High (Strict)"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Confidence Filter") {
                    Picker("Minimum Confidence", selection: $sessionManager.confidenceThreshold) {
                        ForEach(0..<3, id: \.self) { index in
                            Text(confidenceLevels[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Higher confidence removes more noise but may lose detail.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Voxel Downsampling") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Voxel Size")
                            Spacer()
                            Text("\(String(format: "%.1f", sessionManager.voxelSize * 1000)) mm")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: $sessionManager.voxelSize,
                            in: 0.001...0.02,
                            step: 0.001
                        )
                    }
                    Text("Smaller voxels produce denser point clouds; larger voxels reduce noise.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Visualization") {
                    Toggle("Show Mesh Overlay", isOn: $sessionManager.showMesh)
                        .onChange(of: sessionManager.showMesh) {
                            sessionManager.updateMeshVisibility()
                        }
                }

                Section("Scan Info") {
                    LabeledContent("Points Collected") {
                        Text("\(sessionManager.pointCount)")
                            .monospacedDigit()
                    }
                    LabeledContent("Export Format", value: "Binary PLY")
                    LabeledContent("Properties", value: "XYZ + Normals + RGB")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

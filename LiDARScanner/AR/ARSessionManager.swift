import ARKit
import RealityKit
import Combine

class ARSessionManager: NSObject, ObservableObject {

    @Published var pointCount: Int = 0
    @Published var isScanning: Bool = false
    @Published var scanDuration: TimeInterval = 0
    @Published var isLiDARAvailable: Bool = false
    @Published var isProcessing: Bool = false
    @Published var exportedFileURL: URL?

    @Published var confidenceThreshold: Int = 1
    @Published var voxelSize: Float = 0.005
    @Published var showMesh: Bool = true

    var arView: ARView?
    let pointCloudBuilder = PointCloudBuilder()
    private var scanTimer: Timer?
    private var scanStartTime: Date?

    override init() {
        super.init()
        checkLiDARAvailability()
    }

    private func checkLiDARAvailability() {
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }

    func setupARView(_ arView: ARView) {
        self.arView = arView
        arView.session.delegate = self
    }

    func startScanning() {
        guard let arView = arView, isLiDARAvailable else { return }

        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        config.environmentTexturing = .automatic

        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        pointCloudBuilder.reset()
        isScanning = true
        pointCount = 0
        scanDuration = 0
        scanStartTime = Date()

        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let start = self.scanStartTime else { return }
                self.scanDuration = Date().timeIntervalSince(start)
            }
        }

        updateMeshVisibility()
    }

    func stopScanning() {
        guard let arView = arView else { return }
        arView.session.pause()
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
    }

    func exportPointCloud() async -> URL? {
        await MainActor.run { isProcessing = true }

        let rawPoints = pointCloudBuilder.getPoints()
        guard !rawPoints.isEmpty else {
            await MainActor.run { isProcessing = false }
            return nil
        }

        let confThreshold = await MainActor.run { confidenceThreshold }
        let voxel = await MainActor.run { voxelSize }

        let processor = PointCloudProcessor()
        let cleanPoints = processor.process(
            points: rawPoints,
            confidenceThreshold: confThreshold,
            voxelSize: voxel
        )

        let exporter = PLYExporter()
        let url = exporter.export(points: cleanPoints)

        await MainActor.run {
            exportedFileURL = url
            isProcessing = false
        }

        return url
    }

    func updateMeshVisibility() {
        if showMesh {
            arView?.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView?.debugOptions.remove(.showSceneUnderstanding)
        }
    }
}

extension ARSessionManager: ARSessionDelegate {

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        processAnchors(anchors, session: session)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        processAnchors(anchors, session: session)
    }

    private func processAnchors(_ anchors: [ARAnchor], session: ARSession) {
        guard isScanning else { return }
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshAnchors.isEmpty, let frame = session.currentFrame else { return }

        pointCloudBuilder.addOrUpdate(
            meshAnchors: meshAnchors,
            camera: frame.camera,
            capturedImage: frame.capturedImage
        )

        let count = pointCloudBuilder.totalPointCount
        DispatchQueue.main.async { [weak self] in
            self?.pointCount = count
        }
    }
}

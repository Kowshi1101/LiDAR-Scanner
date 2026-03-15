import ARKit
import CoreVideo
import simd

class PointCloudBuilder {

    private var anchorPointsMap: [UUID: [PointCloudPoint]] = [:]
    private let lock = NSLock()

    var totalPointCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return anchorPointsMap.values.reduce(0) { $0 + $1.count }
    }

    func getPoints() -> [PointCloudPoint] {
        lock.lock()
        defer { lock.unlock() }
        return anchorPointsMap.values.flatMap { $0 }
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        anchorPointsMap.removeAll()
    }

    func addOrUpdate(meshAnchors: [ARMeshAnchor], camera: ARCamera, capturedImage: CVPixelBuffer) {
        let imageWidth = CVPixelBufferGetWidth(capturedImage)
        let imageHeight = CVPixelBufferGetHeight(capturedImage)
        let viewportSize = CGSize(width: imageWidth, height: imageHeight)

        CVPixelBufferLockBaseAddress(capturedImage, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(capturedImage, .readOnly) }

        for anchor in meshAnchors {
            let geometry = anchor.geometry
            let vertices = geometry.vertices
            let normals = geometry.normals
            let transform = anchor.transform

            var anchorPoints: [PointCloudPoint] = []
            anchorPoints.reserveCapacity(vertices.count)

            let classificationData = extractClassifications(from: geometry)

            for i in 0..<vertices.count {
                let localVertex = extractVertex(from: vertices, at: i)
                let localNormal = extractVertex(from: normals, at: i)

                let worldPosition = transform.transformPoint(localVertex)
                let worldNormal = simd_normalize(transform.transformDirection(localNormal))

                let projected = camera.projectPoint(
                    worldPosition,
                    orientation: .landscapeRight,
                    viewportSize: viewportSize
                )

                guard isPointVisible(projected, width: imageWidth, height: imageHeight) else {
                    continue
                }

                let color = sampleColor(from: capturedImage, at: projected)

                let confidence: Float = classificationForVertex(
                    index: i,
                    faceCount: geometry.faces.count,
                    classifications: classificationData
                )

                let point = PointCloudPoint(
                    position: worldPosition,
                    normal: worldNormal,
                    color: color,
                    confidence: confidence
                )

                anchorPoints.append(point)
            }

            lock.lock()
            anchorPointsMap[anchor.identifier] = anchorPoints
            lock.unlock()
        }
    }

    // MARK: - Vertex Extraction

    private func extractVertex(from source: ARGeometrySource, at index: Int) -> SIMD3<Float> {
        let pointer = source.buffer.contents().advanced(by: source.offset + source.stride * index)
        return pointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
    }

    private func isPointVisible(_ projected: CGPoint, width: Int, height: Int) -> Bool {
        let x = Int(projected.x)
        let y = Int(projected.y)
        return x >= 0 && x < width && y >= 0 && y < height
    }

    // MARK: - Classification

    private func extractClassifications(from geometry: ARMeshGeometry) -> [UInt8] {
        guard let classification = geometry.classification,
              classification.count > 0 else { return [] }

        var result: [UInt8] = []
        result.reserveCapacity(classification.count)

        for i in 0..<classification.count {
            let ptr = classification.buffer.contents()
                .advanced(by: classification.offset + classification.stride * i)
            result.append(ptr.assumingMemoryBound(to: UInt8.self).pointee)
        }
        return result
    }

    private func classificationForVertex(index: Int, faceCount: Int, classifications: [UInt8]) -> Float {
        guard !classifications.isEmpty else { return 1.0 }
        let faceIndex = min(index / 3, classifications.count - 1)
        // ARMeshClassification: 0 = none (unclassified)
        return classifications[faceIndex] == 0 ? 0.3 : 1.0
    }

    // MARK: - Color Sampling

    private func sampleColor(from pixelBuffer: CVPixelBuffer, at point: CGPoint) -> SIMD3<UInt8> {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let x = Int(point.x)
        let y = Int(point.y)

        guard x >= 0 && x < width && y >= 0 && y < height else {
            return SIMD3<UInt8>(128, 128, 128)
        }

        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2,
              let yPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
              let cbcrPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            return SIMD3<UInt8>(128, 128, 128)
        }

        let yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let cbcrStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

        let yValue = yPlane.advanced(by: y * yStride + x)
            .assumingMemoryBound(to: UInt8.self).pointee
        let cbcrOffset = (y / 2) * cbcrStride + (x / 2) * 2
        let cbValue = cbcrPlane.advanced(by: cbcrOffset)
            .assumingMemoryBound(to: UInt8.self).pointee
        let crValue = cbcrPlane.advanced(by: cbcrOffset + 1)
            .assumingMemoryBound(to: UInt8.self).pointee

        let yf = Float(yValue) - 16.0
        let cbf = Float(cbValue) - 128.0
        let crf = Float(crValue) - 128.0

        let r = 1.164 * yf + 1.596 * crf
        let g = 1.164 * yf - 0.392 * cbf - 0.813 * crf
        let b = 1.164 * yf + 2.017 * cbf

        return SIMD3<UInt8>(
            UInt8(max(0, min(255, r))),
            UInt8(max(0, min(255, g))),
            UInt8(max(0, min(255, b)))
        )
    }
}

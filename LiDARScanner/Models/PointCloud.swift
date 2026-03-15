import Foundation
import simd

struct PointCloudPoint {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var color: SIMD3<UInt8>
    var confidence: Float
}

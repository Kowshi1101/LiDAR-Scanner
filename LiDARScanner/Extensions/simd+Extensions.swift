import simd

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3(columns.3.x, columns.3.y, columns.3.z)
    }

    func transformPoint(_ point: SIMD3<Float>) -> SIMD3<Float> {
        let p = self * SIMD4<Float>(point.x, point.y, point.z, 1.0)
        return SIMD3<Float>(p.x, p.y, p.z)
    }

    func transformDirection(_ direction: SIMD3<Float>) -> SIMD3<Float> {
        let d = self * SIMD4<Float>(direction.x, direction.y, direction.z, 0.0)
        return SIMD3<Float>(d.x, d.y, d.z)
    }
}

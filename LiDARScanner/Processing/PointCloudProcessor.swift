import Foundation
import simd

class PointCloudProcessor {

    func process(
        points: [PointCloudPoint],
        confidenceThreshold: Int,
        voxelSize: Float
    ) -> [PointCloudPoint] {
        guard !points.isEmpty else { return [] }

        var filtered = filterByConfidence(points, threshold: confidenceThreshold)
        filtered = removeStatisticalOutliers(filtered, stdRatio: 2.0)
        filtered = voxelGridDownsample(filtered, voxelSize: voxelSize)

        return filtered
    }

    // MARK: - Confidence Filter

    private func filterByConfidence(_ points: [PointCloudPoint], threshold: Int) -> [PointCloudPoint] {
        let minConfidence: Float
        switch threshold {
        case 0:  minConfidence = 0.0
        case 1:  minConfidence = 0.5
        case 2:  minConfidence = 0.9
        default: minConfidence = 0.5
        }
        return points.filter { $0.confidence >= minConfidence }
    }

    // MARK: - Statistical Outlier Removal

    private func removeStatisticalOutliers(
        _ points: [PointCloudPoint],
        stdRatio: Float
    ) -> [PointCloudPoint] {
        guard points.count > 10 else { return points }

        let cellSize: Float = 0.05
        let invCell = 1.0 / cellSize

        struct GridKey: Hashable {
            let x: Int, y: Int, z: Int
        }

        var grid: [GridKey: [Int]] = [:]
        grid.reserveCapacity(points.count / 4)

        for (i, point) in points.enumerated() {
            let key = GridKey(
                x: Int(floor(point.position.x * invCell)),
                y: Int(floor(point.position.y * invCell)),
                z: Int(floor(point.position.z * invCell))
            )
            grid[key, default: []].append(i)
        }

        var neighborCounts = [Int](repeating: 0, count: points.count)

        for (i, point) in points.enumerated() {
            let cx = Int(floor(point.position.x * invCell))
            let cy = Int(floor(point.position.y * invCell))
            let cz = Int(floor(point.position.z * invCell))

            var count = 0
            for dx in -1...1 {
                for dy in -1...1 {
                    for dz in -1...1 {
                        if let indices = grid[GridKey(x: cx + dx, y: cy + dy, z: cz + dz)] {
                            count += indices.count
                        }
                    }
                }
            }
            neighborCounts[i] = count - 1
        }

        let total = neighborCounts.reduce(0, +)
        let meanCount = Float(total) / Float(neighborCounts.count)
        let variance = neighborCounts.reduce(Float(0)) { sum, count in
            let diff = Float(count) - meanCount
            return sum + diff * diff
        } / Float(neighborCounts.count)
        let stdDev = sqrt(variance)

        let threshold = Int(max(1, meanCount - stdRatio * stdDev))

        return zip(points, neighborCounts).compactMap { point, count in
            count >= threshold ? point : nil
        }
    }

    // MARK: - Voxel Grid Downsampling

    private func voxelGridDownsample(
        _ points: [PointCloudPoint],
        voxelSize: Float
    ) -> [PointCloudPoint] {
        guard voxelSize > 0, !points.isEmpty else { return points }

        struct VoxelKey: Hashable {
            let x: Int, y: Int, z: Int
        }

        struct Accumulator {
            var posSum: SIMD3<Float>
            var normSum: SIMD3<Float>
            var colorSum: SIMD3<Float>
            var confSum: Float
            var count: Int
        }

        let invVoxel = 1.0 / voxelSize
        var voxelMap: [VoxelKey: Accumulator] = [:]
        voxelMap.reserveCapacity(points.count / 2)

        for point in points {
            let key = VoxelKey(
                x: Int(floor(point.position.x * invVoxel)),
                y: Int(floor(point.position.y * invVoxel)),
                z: Int(floor(point.position.z * invVoxel))
            )

            let colorF = SIMD3<Float>(
                Float(point.color.x),
                Float(point.color.y),
                Float(point.color.z)
            )

            if var existing = voxelMap[key] {
                existing.posSum += point.position
                existing.normSum += point.normal
                existing.colorSum += colorF
                existing.confSum += point.confidence
                existing.count += 1
                voxelMap[key] = existing
            } else {
                voxelMap[key] = Accumulator(
                    posSum: point.position,
                    normSum: point.normal,
                    colorSum: colorF,
                    confSum: point.confidence,
                    count: 1
                )
            }
        }

        return voxelMap.values.map { acc in
            let n = Float(acc.count)
            let avgColor = acc.colorSum / n
            let avgNorm = acc.normSum / n
            let normLen = simd_length(avgNorm)
            let safeNormal = normLen > 0.001 ? avgNorm / normLen : SIMD3<Float>(0, 1, 0)

            return PointCloudPoint(
                position: acc.posSum / n,
                normal: safeNormal,
                color: SIMD3<UInt8>(
                    UInt8(max(0, min(255, avgColor.x))),
                    UInt8(max(0, min(255, avgColor.y))),
                    UInt8(max(0, min(255, avgColor.z)))
                ),
                confidence: acc.confSum / n
            )
        }
    }
}

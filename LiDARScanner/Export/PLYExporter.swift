import Foundation

class PLYExporter {

    func export(points: [PointCloudPoint]) -> URL? {
        guard !points.isEmpty else { return nil }

        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileURL = documentsPath.appendingPathComponent("scan_\(timestamp).ply")

        var header = "ply\n"
        header += "format binary_little_endian 1.0\n"
        header += "element vertex \(points.count)\n"
        header += "property float x\n"
        header += "property float y\n"
        header += "property float z\n"
        header += "property float nx\n"
        header += "property float ny\n"
        header += "property float nz\n"
        header += "property uchar red\n"
        header += "property uchar green\n"
        header += "property uchar blue\n"
        header += "end_header\n"

        guard let headerData = header.data(using: .ascii) else { return nil }

        let bytesPerPoint = MemoryLayout<Float>.size * 6 + MemoryLayout<UInt8>.size * 3
        var data = Data(capacity: headerData.count + bytesPerPoint * points.count)
        data.append(headerData)

        for point in points {
            withUnsafeBytes(of: point.position.x) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: point.position.y) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: point.position.z) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: point.normal.x) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: point.normal.y) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: point.normal.z) { data.append(contentsOf: $0) }
            data.append(point.color.x)
            data.append(point.color.y)
            data.append(point.color.z)
        }

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }
}

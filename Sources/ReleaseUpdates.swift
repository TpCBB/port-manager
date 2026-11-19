import Foundation
import CryptoKit

// Tags and package names are part of the release workflow's public contract.
struct PublishedRelease: Decodable {
    struct Asset: Decodable { let name: String; let state: String; let digest: String?; let size: Int64? }
    let tag_name: String
    let draft: Bool
    let assets: [Asset]

    static func components(_ version: String) -> [Int]? {
        let parts = version.components(separatedBy: ".")
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else { return nil }
        let numbers = parts.compactMap(Int.init)
        return numbers.count == 3 ? numbers : nil
    }

    static func newest(in releases: [Self], after version: String) throws -> UpdatePackage? {
        guard var best = components(version) else { throw URLError(.cannotParseResponse) }
        var result: UpdatePackage?
        for release in releases where !release.draft && release.tag_name.hasPrefix("v") {
            let candidate = String(release.tag_name.dropFirst())
            guard let numbers = components(candidate), best.lexicographicallyPrecedes(numbers),
                  let asset = release.assets.first(where: { $0.state == "uploaded" && $0.name == "PortManager-\(candidate)-mac-arm64.dmg" }),
                  let package = UpdatePackage(version: candidate, asset: asset) else { continue }
            best = numbers
            result = package
        }
        return result
    }

    static func check(installed: String) async throws -> UpdatePackage? {
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        var best: UpdatePackage?, page = 1
        while true {
            let url = URL(string: "https://api.github.com/repos/TpCBB/port-manager/releases?per_page=20&page=\(page)")!
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("PortManager", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let releases = try JSONDecoder().decode([Self].self, from: data)
            if let newer = try newest(in: releases, after: best?.version ?? installed) { best = newer }
            if releases.count < 20 { return best }
            page += 1
        }
    }
}

struct UpdatePackage: Equatable {
    let version: String
    let name: String
    let size: Int64
    let hash: String
    var url: URL { URL(string: "https://github.com/TpCBB/port-manager/releases/download/v\(version)/\(name)")! }

    init?(version: String, asset: PublishedRelease.Asset) {
        guard PublishedRelease.components(version) != nil, asset.name == "PortManager-\(version)-mac-arm64.dmg",
              let digest = asset.digest, digest.hasPrefix("sha256:"), let size = asset.size,
              size > 0, size <= 256 * 1024 * 1024 else { return nil }
        let hash = String(digest.dropFirst(7))
        guard hash.utf8.count == 64, hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        self.version = version; self.name = asset.name; self.size = size; self.hash = hash
    }

    func download(into parent: URL, configuration: URLSessionConfiguration = .ephemeral, progress: @Sendable (Int) async -> Void) async throws -> URL {
        let fm = FileManager.default, dir = parent.appendingPathComponent("PortManager-" + UUID().uuidString)
        try fm.createDirectory(at: dir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let partial = dir.appendingPathComponent("download.part"), final = dir.appendingPathComponent(name)
        var complete = false
        defer { if !complete { try? fm.removeItem(at: dir) } }
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: URLRequest(url: url, timeoutInterval: 30))
        guard (response as? HTTPURLResponse)?.statusCode == 200, response.url?.scheme == "https" else { throw URLError(.badServerResponse) }
        try Data().write(to: partial, options: .withoutOverwriting)
        let file = try FileHandle(forWritingTo: partial)
        var hasher = SHA256(), count: Int64 = 0, chunk = Data(), last = -1
        defer { try? file.close() }
        for try await byte in bytes {
            count += 1
            guard count <= size else { throw UpdateError.integrity }
            chunk.append(byte)
            if chunk.count == 65536 {
                try file.write(contentsOf: chunk); hasher.update(data: chunk); chunk.removeAll(keepingCapacity: true)
                let percent = Int(count * 100 / size)
                if percent != last { last = percent; await progress(percent) }
            }
        }
        try file.write(contentsOf: chunk); hasher.update(data: chunk)
        try file.close()
        guard count == size, hasher.finalize().map({ String(format: "%02x", $0) }).joined() == hash else { throw UpdateError.integrity }
        try fm.moveItem(at: partial, to: final)
        complete = true
        await progress(100)
        return final
    }
}

enum UpdateError: Error { case integrity }

//
//  ImageCache.swift
//  inveasy
//

import Foundation
import UIKit
import CryptoKit

/// Two-tier image cache: an `NSCache` for hot in-memory lookups and a
/// FileManager-backed disk store for cold launches.
///
/// We don't rely on `URLCache` alone because product image URLs often come
/// from a CDN with conservative `Cache-Control` headers; this gives us
/// predictable behaviour with explicit bounds.
actor ImageCache {
    static let shared = ImageCache()

    private let memory: NSCache<NSString, UIImage>
    private let diskDirectory: URL
    private let fileManager = FileManager.default
    private let session: URLSession

    /// In-flight downloads keyed by URL — concurrent requests for the same
    /// image share a single network round-trip.
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    init(
        memoryLimitMB: Int = 50,
        diskFolderName: String = "InveasyImages",
        session: URLSession = .shared
    ) {
        self.session = session

        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = memoryLimitMB * 1024 * 1024
        self.memory = cache

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let folder = caches.appendingPathComponent(diskFolderName, isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        self.diskDirectory = folder
    }

    /// Returns the cached image immediately if available in memory.
    /// Otherwise loads from disk, falling back to a network fetch.
    func image(for url: URL) async throws -> UIImage {
        if let cached = memory.object(forKey: cacheKey(for: url)) {
            return cached
        }

        if let disk = loadFromDisk(url) {
            memory.setObject(disk.image, forKey: cacheKey(for: url), cost: disk.byteCount)
            return disk.image
        }

        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<UIImage, Error> { [session, diskDirectory, fileManager] in
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            let fileURL = diskDirectory.appendingPathComponent(Self.filename(for: url))
            try? data.write(to: fileURL, options: .atomic)
            _ = fileManager // silence capture warning; needed for sandbox isolation
            return image
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }

        let image = try await task.value
        memory.setObject(image, forKey: cacheKey(for: url), cost: imageByteCount(image))
        return image
    }

    /// Erase both tiers — useful for sign-out or a manual "clear cache" action.
    func clear() {
        memory.removeAllObjects()
        if let entries = try? fileManager.contentsOfDirectory(at: diskDirectory, includingPropertiesForKeys: nil) {
            for url in entries {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    // MARK: - Internals

    private func loadFromDisk(_ url: URL) -> (image: UIImage, byteCount: Int)? {
        let fileURL = diskDirectory.appendingPathComponent(Self.filename(for: url))
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return (image, data.count)
    }

    private func imageByteCount(_ image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 0 }
        return cg.bytesPerRow * cg.height
    }

    private func cacheKey(for url: URL) -> NSString {
        url.absoluteString as NSString
    }

    private static func filename(for url: URL) -> String {
        let digest = Insecure.SHA1.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

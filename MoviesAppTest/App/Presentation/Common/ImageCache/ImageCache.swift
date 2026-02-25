import Foundation
import SwiftUI

actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private var activeTasks: [URL: Task<PlatformImage, Error>] = [:]

    init(memoryLimit: Int = 50) {
        cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImageCache", isDirectory: true)
        memoryCache.countLimit = memoryLimit
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func image(for url: URL) async throws -> PlatformImage {
        let key = url.absoluteString as NSString

        if let cachedNSData = memoryCache.object(forKey: key) {
            let cachedData = Data(referencing: cachedNSData)
            if let image = await PlatformImageDecoder.decode(cachedData) {
                return image
            }
        }

        let diskPath = diskURL(for: url)
        if let data = try? Data(contentsOf: diskPath),
           let image = await PlatformImageDecoder.decode(data) {
            memoryCache.setObject(data as NSData, forKey: key)
            return image
        }

        if let existingTask = activeTasks[url] {
            return try await existingTask.value
        }

        let task = Task<PlatformImage, Error> {
            let (data, response) = try await URLSession.shared.data(from: url)
            let decodedImage = await PlatformImageDecoder.decode(data)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = decodedImage else {
                throw ImageCacheError.invalidImage
            }

            try? data.write(to: diskPath)
            memoryCache.setObject(data as NSData, forKey: key)
            return image
        }

        activeTasks[url] = task
        defer { activeTasks[url] = nil }

        return try await task.value
    }

    func clearMemory() {
        memoryCache.removeAllObjects()
    }

    func clearDisk() throws {
        try fileManager.removeItem(at: cacheDirectory)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func diskURL(for url: URL) -> URL {
        let filename = url.absoluteString.data(using: .utf8)!
            .base64EncodedString()
            .prefix(64)
        return cacheDirectory.appendingPathComponent(String(filename))
    }
}

#if canImport(UIKit)
@preconcurrency import UIKit

typealias PlatformImage = UIImage
#elseif canImport(AppKit)
@preconcurrency import AppKit

typealias PlatformImage = NSImage
#endif

enum ImageCacheError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "Failed to load image."
    }
}

@MainActor
private enum PlatformImageDecoder {
    static func decode(_ data: Data) -> PlatformImage? {
        PlatformImage(data: data)
    }
}

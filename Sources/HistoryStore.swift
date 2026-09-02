import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct HistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let filename: String
    let pixelWidth: Int
    let pixelHeight: Int
    let scale: CGFloat

    var title: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(pixelWidth)×\(pixelHeight) · \(formatter.string(from: createdAt))"
    }

    init(id: UUID, createdAt: Date, filename: String, pixelWidth: Int, pixelHeight: Int, scale: CGFloat) {
        self.id = id
        self.createdAt = createdAt
        self.filename = filename
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        createdAt = try box.decode(Date.self, forKey: .createdAt)
        filename = try box.decode(String.self, forKey: .filename)
        pixelWidth = try box.decode(Int.self, forKey: .pixelWidth)
        pixelHeight = try box.decode(Int.self, forKey: .pixelHeight)
        scale = try box.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 2
    }
}

@MainActor
final class HistoryStore {
    static let shared = HistoryStore()
    static let cap = 20

    private(set) var items: [HistoryItem] = []
    private let folder: URL
    private let indexURL: URL

    private init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        folder = root
            .appendingPathComponent(ProductIdentity.supportFolderName, isDirectory: true)
            .appendingPathComponent(ProductIdentity.historyFolderName, isDirectory: true)
        indexURL = folder.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        load()
    }

    func add(image: CGImage, scale: CGFloat) {
        let id = UUID()
        let filename = "\(id.uuidString).png"
        let url = folder.appendingPathComponent(filename)
        do {
            try Export.writePNG(image, to: url)
        } catch {
            NSLog("Frame: history write failed: %@", error.localizedDescription)
            return
        }
        let item = HistoryItem(
            id: id,
            createdAt: Date(),
            filename: filename,
            pixelWidth: image.width,
            pixelHeight: image.height,
            scale: scale
        )
        items.insert(item, at: 0)
        trim()
        saveIndex()
    }

    func image(for item: HistoryItem) -> CGImage? {
        let url = folder.appendingPathComponent(item.filename)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    func clear() {
        for item in items {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(item.filename))
        }
        items = []
        saveIndex()
    }

    private func trim() {
        while items.count > Self.cap {
            let dropped = items.removeLast()
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(dropped.filename))
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoded = (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
        items = decoded.filter {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0.filename).path)
        }
    }

    private func saveIndex() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}

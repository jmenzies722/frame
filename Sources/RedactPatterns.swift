import Foundation

enum RedactPatterns {
    private static let patterns: [NSRegularExpression] = {
        let raw = [
            #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
            #"sk-[A-Za-z0-9]{10,}"#,
            #"AKIA[A-Z0-9]{16}"#,
            #"ghp_[A-Za-z0-9]{20,}"#,
            #"xox[baprs]-[A-Za-z0-9\-]+"#,
            #"Bearer\s+[A-Za-z0-9\-._~+/]+=*"#,
            #"-----BEGIN(?: [A-Z]+)? PRIVATE KEY-----"#,
        ]
        return raw.compactMap {
            try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
        }
    }()

    static func secretRanges(in text: String) -> [NSRange] {
        let full = NSRange(text.startIndex..<text.endIndex, in: text)
        var hits: [NSRange] = []
        for regex in patterns {
            for match in regex.matches(in: text, options: [], range: full) {
                hits.append(match.range)
            }
        }
        return merge(hits)
    }

    static func containsSecret(_ text: String) -> Bool {
        !secretRanges(in: text).isEmpty
    }

    static func isPEMStart(_ text: String) -> Bool {
        text.range(of: "-----BEGIN", options: .caseInsensitive) != nil
            && text.range(of: "PRIVATE KEY", options: .caseInsensitive) != nil
    }

    static func isPEMEnd(_ text: String) -> Bool {
        text.range(of: "-----END", options: .caseInsensitive) != nil
            && text.range(of: "PRIVATE KEY", options: .caseInsensitive) != nil
    }

    static func looksLikePEMBody(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 16 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+/="))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func merge(_ ranges: [NSRange]) -> [NSRange] {
        let sorted = ranges.sorted { $0.location < $1.location }
        var merged: [NSRange] = []
        for range in sorted {
            guard let last = merged.last else {
                merged.append(range)
                continue
            }
            let lastEnd = last.location + last.length
            if range.location <= lastEnd {
                let end = max(lastEnd, range.location + range.length)
                merged[merged.count - 1] = NSRange(location: last.location, length: end - last.location)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}

//
//  ExifDataView.swift
//  MobileLens-Lite-iOS
//
//  Created by Codex on 01/06/2026.
//

import SwiftUI
import ImageIO

struct ExifDataView: View {
    let imageData: Data?

    private var exifItems: [ExifItem] {
        guard let imageData else { return [] }
        return ExifReader.items(from: imageData)
    }

    var body: some View {
        List {
            if exifItems.isEmpty {
                ContentUnavailableView(
                    "No EXIF Data",
                    systemImage: "info.circle",
                    description: Text("This image does not include readable EXIF metadata.")
                )
            } else {
                ForEach(exifItems) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.headline)
                        Text(item.value)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("EXIF Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExifItem: Identifiable {
    let id = UUID()
    let name: String
    let value: String
}

enum ExifReader {
    static func items(from data: Data) -> [ExifItem] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return []
        }

        return flatten(properties)
            .map { ExifItem(name: $0.key, value: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func flatten(_ dictionary: [String: Any], prefix: String? = nil) -> [(key: String, value: String)] {
        dictionary.flatMap { key, value -> [(key: String, value: String)] in
            let cleanKey = key
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: "}", with: "")
            let displayKey = [prefix, cleanKey].compactMap { $0 }.joined(separator: " ")

            if let nestedDictionary = value as? [String: Any] {
                return flatten(nestedDictionary, prefix: displayKey)
            }

            if let array = value as? [Any] {
                let arrayValue = array.map { String(describing: $0) }.joined(separator: ", ")
                return [(displayKey, arrayValue)]
            }

            return [(displayKey, String(describing: value))]
        }
    }
}

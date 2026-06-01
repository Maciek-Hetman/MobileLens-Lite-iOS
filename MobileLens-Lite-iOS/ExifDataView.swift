//
//  ExifDataView.swift
//  MobileLens-Lite-iOS
//
//  Created by Codex on 01/06/2026.
//

import SwiftUI
import ImageIO
import CoreData

struct ExifDataView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let imageData: Data?
    @Binding var savedItemID: Int16?

    @State private var saveErrorMessage: String?

    private var mappedData: ExifMappedData? {
        guard let imageData else { return nil }
        return ExifReader.mappedData(from: imageData)
    }

    private var savedItem: Item? {
        guard let savedItemID else { return nil }

        let request = NSFetchRequest<Item>(entityName: "Item")
        request.predicate = NSPredicate(format: "id == %d", savedItemID)
        request.fetchLimit = 1

        return try? viewContext.fetch(request).first
    }

    var body: some View {
        List {
            if let mappedData {
                if let savedItem {
                    ExifRow(name: "Focal Length", value: "\(Double(savedItem.focal_length_mm).formattedExifValue) mm")
                    ExifRow(name: "Aperture", value: "f/\(Double(savedItem.aperture).formattedExifValue)")
                    ExifRow(name: "Resolution", value: "\(Double(savedItem.resolution_mp).formattedExifValue) MP")
                    ExifRow(name: "Crop Factor", value: Double(savedItem.crop_factor).formattedExifValue)
                    ExifRow(name: "35mm Equivalent Focal Length", value: "\(mappedData.focalLengthIn35mmFilm.formattedExifValue) mm")
                    ExifRow(name: "35mm Equivalent Aperture", value: "f/\(mappedData.aperture35mmEquivalent.formattedExifValue)")
                } else {
                    ExifRow(name: "Focal Length", value: "\(mappedData.focalLength.formattedExifValue) mm")
                    ExifRow(name: "Aperture", value: "f/\(mappedData.fNumber.formattedExifValue)")
                    ExifRow(name: "Resolution", value: "\(mappedData.resolutionMegapixels.formattedExifValue) MP")
                    ExifRow(name: "Crop Factor", value: mappedData.cropFactor.formattedExifValue)
                    ExifRow(name: "35mm Equivalent Focal Length", value: "\(mappedData.focalLengthIn35mmFilm.formattedExifValue) mm")
                    ExifRow(name: "35mm Equivalent Aperture", value: "f/\(mappedData.aperture35mmEquivalent.formattedExifValue)")
                }

                if savedItemID != nil {
                    Section {
                        Label("Saved to database", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                } else if let saveErrorMessage {
                    Section {
                        Label(saveErrorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No EXIF Data",
                    systemImage: "info.circle",
                    description: Text("This image does not include all metadata needed for the Core Data model.")
                )
            }
        }
        .navigationTitle("EXIF Data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            saveMappedItemIfNeeded()
        }
    }

    private func saveMappedItemIfNeeded() {
        guard savedItemID == nil, let mappedData else { return }

        let item = Item(context: viewContext)
        let itemID = nextItemID()
        item.id = itemID
        item.focal_length_mm = Float(mappedData.focalLength)
        item.crop_factor = Float(mappedData.cropFactor)
        item.aperture = Float(mappedData.fNumber)
        item.resolution_mp = Float(mappedData.resolutionMegapixels)

        do {
            try viewContext.save()
            savedItemID = itemID
        } catch {
            viewContext.rollback()
            saveErrorMessage = "Could not save EXIF data"
        }
    }

    private func nextItemID() -> Int16 {
        let request = NSFetchRequest<Item>(entityName: "Item")
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        request.fetchLimit = 1

        guard let lastItem = try? viewContext.fetch(request).first else {
            return 1
        }

        return lastItem.id + 1
    }
}

struct ExifRow: View {
    let name: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.headline)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ExifMappedData {
    let fNumber: Double
    let focalLength: Double
    let focalLengthIn35mmFilm: Double
    let pixelWidth: Int
    let pixelHeight: Int

    var cropFactor: Double {
        focalLengthIn35mmFilm / focalLength
    }

    var aperture35mmEquivalent: Double {
        cropFactor * fNumber
    }

    var resolutionMegapixels: Double {
        Double(pixelWidth * pixelHeight) / 1_000_000
    }
}

enum ExifReader {
    static func mappedData(from data: Data) -> ExifMappedData? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }

        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]

        guard let fNumber = doubleValue(for: kCGImagePropertyExifFNumber, in: exif),
              let focalLength = doubleValue(for: kCGImagePropertyExifFocalLength, in: exif),
              let focalLengthIn35mmFilm = doubleValue(for: kCGImagePropertyExifFocalLenIn35mmFilm, in: exif),
              let pixelWidth = intValue(for: kCGImagePropertyExifPixelXDimension, in: exif)
                ?? intValue(for: kCGImagePropertyPixelWidth, in: properties),
              let pixelHeight = intValue(for: kCGImagePropertyExifPixelYDimension, in: exif)
                ?? intValue(for: kCGImagePropertyPixelHeight, in: properties),
              focalLength > 0 else {
            return nil
        }

        return ExifMappedData(
            fNumber: fNumber,
            focalLength: focalLength,
            focalLengthIn35mmFilm: focalLengthIn35mmFilm,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )
    }

    private static func doubleValue(for key: CFString, in dictionary: [String: Any]?) -> Double? {
        guard let value = dictionary?[key as String] else { return nil }
        return numberValue(from: value)
    }

    private static func intValue(for key: CFString, in dictionary: [String: Any]?) -> Int? {
        guard let value = dictionary?[key as String],
              let number = numberValue(from: value) else {
            return nil
        }

        return Int(number)
    }

    private static func numberValue(from value: Any) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let string = value as? String {
            return Double(string)
        }

        return nil
    }
}

private extension Double {
    var formattedExifValue: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }
}

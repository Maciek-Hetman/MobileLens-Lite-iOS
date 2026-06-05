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
    @Environment(\.dismiss) private var dismiss

    let imageData: Data?
    @Binding var savedCameraID: Int16?
    let onSaveComplete: () -> Void

    @State private var isShowingSaveDetails = false
    @State private var isShowingEditDetails = false
    @State private var isShowingDeleteConfirmation = false
    @State private var brand = ""
    @State private var model = ""
    @State private var editBrand = ""
    @State private var editModel = ""
    @State private var editFocalLength = ""
    @State private var editAperture = ""
    @State private var editResolution = ""
    @State private var editCropFactor = ""
    @State private var saveErrorMessage: String?
    @State private var editErrorMessage: String?
    @State private var deleteErrorMessage: String?

    private var mappedData: ExifMappedData? {
        guard let imageData else { return nil }
        return ExifReader.mappedData(from: imageData)
    }

    private var savedCamera: Camera? {
        guard let savedCameraID else { return nil }

        let request = NSFetchRequest<Camera>(entityName: "Camera")
        request.predicate = NSPredicate(format: "id == %d", savedCameraID)
        request.fetchLimit = 1

        return try? viewContext.fetch(request).first
    }

    var body: some View {
        List {
            if let savedCamera {
                ExifRow(name: "Brand", value: savedCamera.toPhone?.brand ?? "Not provided")
                ExifRow(name: "Model", value: savedCamera.toPhone?.model ?? "Not provided")
                ExifRow(name: "Focal Length", value: "\(Double(savedCamera.focal_length_mm).formattedExifValue) mm")
                ExifRow(name: "Aperture", value: "f/\(Double(savedCamera.aperture).formattedExifValue)")
                ExifRow(name: "Resolution", value: "\(Double(savedCamera.resolution_mp).formattedExifValue) MP")
                ExifRow(name: "Crop Factor", value: Double(savedCamera.crop_factor).formattedExifValue)
                ExifRow(name: "35mm Equivalent Focal Length", value: "\(savedCamera.equivalentFocalLength.formattedExifValue) mm")
                ExifRow(name: "35mm Equivalent Aperture", value: "f/\(savedCamera.equivalentAperture.formattedExifValue)")
            } else if let mappedData {
                ExifRow(name: "Brand", value: "Not saved yet")
                ExifRow(name: "Model", value: "Not saved yet")
                ExifRow(name: "Focal Length", value: "\(mappedData.focalLength.formattedExifValue) mm")
                ExifRow(name: "Aperture", value: "f/\(mappedData.fNumber.formattedExifValue)")
                ExifRow(name: "Resolution", value: "\(mappedData.resolutionMegapixels.formattedExifValue) MP")
                ExifRow(name: "Crop Factor", value: mappedData.cropFactor.formattedExifValue)
                ExifRow(name: "35mm Equivalent Focal Length", value: "\(mappedData.focalLengthIn35mmFilm.formattedExifValue) mm")
                ExifRow(name: "35mm Equivalent Aperture", value: "f/\(mappedData.aperture35mmEquivalent.formattedExifValue)")
            } else {
                ContentUnavailableView(
                    "No EXIF Data",
                    systemImage: "info.circle",
                    description: Text("This image does not include all metadata needed for the Core Data model.")
                )
            }
        }
        .appBarTitle("EXIF Data")
        .safeAreaInset(edge: .bottom) {
            if let savedCamera {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button {
                            prepareEditDetails(for: savedCamera)
                            isShowingEditDetails = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Edit Entry", systemImage: "pencil")
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete", systemImage: "trash")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    if let editErrorMessage {
                        Label(editErrorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let deleteErrorMessage {
                        Label(deleteErrorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(.bar)
            } else if mappedData != nil {
                VStack(spacing: 8) {
                    Button {
                        isShowingSaveDetails = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Save to Database", systemImage: "tray.and.arrow.down")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if let saveErrorMessage {
                        Label(saveErrorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(.bar)
            }
        }
        .alert("Save Lens Details", isPresented: $isShowingSaveDetails) {
            TextField("Brand", text: $brand)
            TextField("Model", text: $model)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveMappedItem()
            }
        } message: {
            Text("Enter the brand and model before saving this photo data.")
        }
        .sheet(isPresented: $isShowingEditDetails) {
            NavigationStack {
                Form {
                    Section("Phone") {
                        LabeledContent("Brand") {
                            TextField("Not provided", text: $editBrand)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Model") {
                            TextField("Not provided", text: $editModel)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Section("Lens Data") {
                        LabeledContent("Focal Length (mm)") {
                            TextField("0", text: $editFocalLength)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Aperture (f-number)") {
                            TextField("0", text: $editAperture)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Resolution (MP)") {
                            TextField("0", text: $editResolution)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Crop Factor (x)") {
                            TextField("0", text: $editCropFactor)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    if let editErrorMessage {
                        Label(editErrorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
                .appBarTitle("Edit Entry")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editErrorMessage = nil
                            isShowingEditDetails = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            updateSavedItem()
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Entry?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Entry", role: .destructive) {
                deleteSavedItem()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This saved EXIF entry will be removed from the database.")
        }
    }

    private func saveMappedItem() {
        guard savedCameraID == nil, let mappedData else { return }
        saveErrorMessage = nil

        let phone = existingPhone(brand: brand, model: model) ?? newPhone(brand: brand, model: model)

        let camera = Camera(context: viewContext)
        let cameraID = nextCameraID()
        camera.id = cameraID
        camera.focal_length_mm = Float(mappedData.focalLength)
        camera.crop_factor = Float(mappedData.cropFactor)
        camera.aperture = Float(mappedData.fNumber)
        camera.resolution_mp = Float(mappedData.resolutionMegapixels)
        camera.toPhone = phone

        do {
            try viewContext.save()
            savedCameraID = cameraID
            onSaveComplete()
        } catch {
            viewContext.rollback()
            saveErrorMessage = "Could not save EXIF data"
        }
    }

    private func prepareEditDetails(for camera: Camera) {
        editErrorMessage = nil
        deleteErrorMessage = nil
        editBrand = camera.toPhone?.brand ?? ""
        editModel = camera.toPhone?.model ?? ""
        editFocalLength = Double(camera.focal_length_mm).formattedExifValue
        editAperture = Double(camera.aperture).formattedExifValue
        editResolution = Double(camera.resolution_mp).formattedExifValue
        editCropFactor = Double(camera.crop_factor).formattedExifValue
    }

    private func updateSavedItem() {
        guard let savedCamera else { return }

        editErrorMessage = nil

        guard let focalLength = positiveDouble(from: editFocalLength),
              let aperture = positiveDouble(from: editAperture),
              let resolution = positiveDouble(from: editResolution),
              let cropFactor = positiveDouble(from: editCropFactor) else {
            editErrorMessage = "Enter positive numbers for all lens data."
            return
        }

        let oldPhone = savedCamera.toPhone
        let updatedPhone = existingPhone(brand: editBrand, model: editModel) ?? newPhone(brand: editBrand, model: editModel)

        savedCamera.focal_length_mm = Float(focalLength)
        savedCamera.aperture = Float(aperture)
        savedCamera.resolution_mp = Float(resolution)
        savedCamera.crop_factor = Float(cropFactor)
        savedCamera.toPhone = updatedPhone

        if let oldPhone, oldPhone != updatedPhone, !hasOtherCameras(for: oldPhone, excluding: savedCamera) {
            viewContext.delete(oldPhone)
        }

        do {
            try viewContext.save()
            isShowingEditDetails = false
            onSaveComplete()
        } catch {
            viewContext.rollback()
            editErrorMessage = "Could not update entry"
        }
    }

    private func deleteSavedItem() {
        guard let savedCamera else { return }

        deleteErrorMessage = nil
        let phone = savedCamera.toPhone
        viewContext.delete(savedCamera)

        if let phone, !hasOtherCameras(for: phone, excluding: savedCamera) {
            viewContext.delete(phone)
        }

        do {
            try viewContext.save()
            savedCameraID = nil
            onSaveComplete()
            dismiss()
        } catch {
            viewContext.rollback()
            deleteErrorMessage = "Could not delete entry"
        }
    }

    private func existingPhone(brand: String, model: String) -> Phone? {
        guard let trimmedBrand = trimmedOptional(brand),
              let trimmedModel = trimmedOptional(model) else {
            return nil
        }

        let request = NSFetchRequest<Phone>(entityName: "Phone")
        request.predicate = NSPredicate(
            format: "brand ==[c] %@ AND model ==[c] %@",
            trimmedBrand,
            trimmedModel
        )
        request.fetchLimit = 1

        return try? viewContext.fetch(request).first
    }

    private func newPhone(brand: String, model: String) -> Phone {
        let phone = Phone(context: viewContext)
        phone.id = nextPhoneID()
        phone.brand = trimmedOptional(brand)
        phone.model = trimmedOptional(model)
        return phone
    }

    private func trimmedOptional(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func positiveDouble(from value: String) -> Double? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let number = Double(trimmedValue), number > 0 else {
            return nil
        }

        return number
    }

    private func hasOtherCameras(for phone: Phone, excluding camera: Camera) -> Bool {
        let request = NSFetchRequest<Camera>(entityName: "Camera")
        request.predicate = NSPredicate(format: "toPhone == %@ AND self != %@", phone, camera)
        request.fetchLimit = 1

        return ((try? viewContext.count(for: request)) ?? 0) > 0
    }

    private func nextCameraID() -> Int16 {
        let request = NSFetchRequest<Camera>(entityName: "Camera")
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        request.fetchLimit = 1

        guard let lastCamera = try? viewContext.fetch(request).first else {
            return 1
        }

        return lastCamera.id + 1
    }

    private func nextPhoneID() -> Int16 {
        let request = NSFetchRequest<Phone>(entityName: "Phone")
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        request.fetchLimit = 1

        guard let lastPhone = try? viewContext.fetch(request).first else {
            return 1
        }

        return lastPhone.id + 1
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

private extension Camera {
    var equivalentFocalLength: Double {
        Double(focal_length_mm * crop_factor)
    }

    var equivalentAperture: Double {
        Double(aperture * crop_factor)
    }
}

private extension Double {
    var formattedExifValue: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }
}

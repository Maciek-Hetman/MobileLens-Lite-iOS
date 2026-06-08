# Aplikacja do przedstawiania danych technicznych apratów z danych EXIF

## Pobranie zdjecia od użytkownika:

./MobileLens-Lite-iOS/ContentView.swift od linii 64
```swift
PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()) {
                        HStack {
                            Spacer()
                            Label("Choose Photo", systemImage: "photo")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .onChange(of: selectedItem) { oldValue, newValue in
                        guard let newValue else { return }
                        Task {
                            if let data = try? await newValue.loadTransferable(type: Data.self) {
                                selectedImageData = data
                                savedCameraID = nil
                            }
                        }
                    }

                NavigationLink {
                    ExifDataView(imageData: selectedImageData, savedCameraID: $savedCameraID, onSaveComplete: {
                        selectedImageData = nil
                        selectedItem = nil
                    })
                } label: {
                    HStack {
                        Spacer()
                        Label("View EXIF Data", systemImage: "info.circle")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(selectedImageData == nil)
```

Po wybraniu zdjęcia przez użytkownika dane są ładowane do zmiennej `selectedImageData`. `NavigationLink` zabiera użytkownika do `ExifDataView` który wyświetla specyfikacje.

## Obliczenie i wyświetlenie specyfikacji

### Struktura zawierająca specyfikacje 

./MobileLens-Lite-iOS/ExifDataView.swift od linii 416

```swift
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
```

### Ekstrakcja specyfikacji z danych EXIF

./MobileLens-Lite-iOS/ExifDataView.swift od linii 436

```swift
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
```

### Funkcja zapisująca dane do CoreData

./MobileLens-Lite-iOS/ExifDataView.swift od linii 232

```swift
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
```

### Wyświetlanie danych

Interfejs ma 2 wersje - jedna dla danych niezapisanych jeszcze do bazy danych (zawiera przycisk do zapisu) oraz jedna dla danych już w bazie, która zawiera przyciski do edycji oraz usunięcia rekordu z bazy danych.

./MobileLens-Lite-iOS/ExifDataView.swift od linii 53 zawiera listę danych:

```swift
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
```

./MobileLens-Lite-iOS/ExifDataView.swift od linii 81 zawiera przyciski nawigacyjne dla obu wersji interfejsu:

```swift
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
```

./MobileLens-Lite-iOS/ExifDataView.swift od linii 149 zawiera formularz do podania modelu i marki telefonu przed dodaniem danych do CoreData:

```swift
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
```

./MobileLens-Lite-iOS/ExifDataView.swift od linii 159 zawiera formularz edycji danych z CoreData:

```swift
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
```

./MobileLens-Lite-iOS/ExifDataView.swift od linii 218 zawiera dialog do potwierdzenia czy użytkownik chce usunąć rekord z CoreData:

```swift
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
```

## Model CoreData

CoreData zawiera 2 encje:
  - Camera
  - Phone

### Camera

Encja zawiera pola:

  - id
  - aperture
  - crop_factor
  - focal_length_mm
  - resolution_mp

### Phone

Encja zawiera pola:

  - id
  - brand
  - model

### Relacje

Jest jedna relacja wiele-do-wielu między encjami `toCamera` oraz `toPhone`

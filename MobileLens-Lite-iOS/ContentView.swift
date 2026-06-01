//
//  ContentView.swift
//  MobileLens-Lite-iOS
//
//  Created by Maciej Hetman on 28/05/2026.
//

import SwiftUI
import CoreData
import PhotosUI

struct ContentView: View {
    var body: some View {
        TabView {
            UploadTabView()
                .tabItem {
                    Label("Upload", systemImage: "square.and.arrow.up")
                }

            DatabaseTabView()
                .tabItem {
                    Label("Database", systemImage: "tray.full")
                }
        }
    }
}

struct UploadTabView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var savedCameraID: Int16? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Group {
                    if let selectedImageData,
                       let uiImage = UIImage(data: selectedImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 4)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                .foregroundStyle(.secondary)
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("No photo selected")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                        .frame(maxHeight: 320)
                    }
                }
                .frame(maxWidth: .infinity)

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

                Spacer()
            }
            .padding()
            .appBarTitle("Upload")
        }
    }
}

struct DatabaseTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Camera.id, ascending: true)],
        animation: .default)
    private var cameras: FetchedResults<Camera>

    var body: some View {
        NavigationStack {
            Group {
                if cameras.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray.full")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Your saved items will appear here.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(cameras) { camera in
                            NavigationLink {
                                ExifDataView(imageData: nil, savedCameraID: .constant(camera.id), onSaveComplete: { })
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(camera.toPhone?.brand ?? "Not provided")
                                        .font(.headline)
                                    Text(camera.toPhone?.model ?? "Not provided")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteCameras)
                    }
                }
            }
            .appBarTitle("Database")
        }
    }

    private func deleteCameras(offsets: IndexSet) {
        offsets.map { cameras[$0] }.forEach { camera in
            let phone = camera.toPhone
            viewContext.delete(camera)

            if let phone, !hasOtherCameras(for: phone, excluding: camera) {
                viewContext.delete(phone)
            }
        }

        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
        }
    }

    private func hasOtherCameras(for phone: Phone, excluding camera: Camera) -> Bool {
        let request = NSFetchRequest<Camera>(entityName: "Camera")
        request.predicate = NSPredicate(format: "toPhone == %@ AND self != %@", phone, camera)
        request.fetchLimit = 1

        return ((try? viewContext.count(for: request)) ?? 0) > 0
    }
}

private extension Double {
    var formattedExifValue: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }
}

extension View {
    func appBarTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
    }
}

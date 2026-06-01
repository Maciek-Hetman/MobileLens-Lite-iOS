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

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Upload a photo")
                    .font(.title2)
                    .fontWeight(.semibold)

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
                        Text("Choose Photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .onChange(of: selectedItem) { oldValue, newValue in
                        guard let newValue else { return }
                        Task {
                            if let data = try? await newValue.loadTransferable(type: Data.self) {
                                selectedImageData = data
                            }
                        }
                    }

                NavigationLink {
                    ExifDataView(imageData: selectedImageData)
                } label: {
                    Text("View EXIF Data")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(selectedImageData == nil)

                Spacer()
            }
            .padding()
        }
    }
}

struct DatabaseTabView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.full")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Database")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Your saved items will appear here.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

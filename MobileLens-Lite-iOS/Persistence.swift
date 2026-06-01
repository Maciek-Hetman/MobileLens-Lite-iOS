//
//  Persistence.swift
//  MobileLens-Lite-iOS
//
//  Created by Maciej Hetman on 28/05/2026.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for index in 1...3 {
            let phone = Phone(context: viewContext)
            phone.id = Int16(index)
            phone.brand = "Sample Brand"
            phone.model = "Sample Model \(index)"

            let camera = Camera(context: viewContext)
            camera.id = Int16(index)
            camera.focal_length_mm = 24
            camera.aperture = 1.8
            camera.crop_factor = 2
            camera.resolution_mp = 12
            camera.toPhone = phone
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MobileLens_Lite_iOS")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

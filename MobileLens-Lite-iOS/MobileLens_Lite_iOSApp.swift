//
//  MobileLens_Lite_iOSApp.swift
//  MobileLens-Lite-iOS
//
//  Created by Maciej Hetman on 28/05/2026.
//

import SwiftUI
import CoreData

@main
struct MobileLens_Lite_iOSApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

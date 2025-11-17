//
//  Workout_TrackerApp.swift
//  Workout Tracker
//
//  Created by Christopher McDonald on 18/11/2025.
//

import SwiftUI
import CoreData

@main
struct Workout_TrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

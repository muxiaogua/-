//
//  TeamWorkbenchApp.swift
//  团队工作台
//

import SwiftUI

@main
struct TeamWorkbenchApp: App {
    @StateObject private var store = WorkbenchStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .navigationTitle("")
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            SidebarCommands()
        }
    }
}

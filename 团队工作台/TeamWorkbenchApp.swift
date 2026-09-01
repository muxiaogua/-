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
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }
    }
}

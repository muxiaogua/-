//
//  ContentView.swift
//  团队工作台
//

import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var store: WorkbenchStore
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 200, idealWidth: 220)
        } detail: {
            switch store.selectedNavigation {
            case .dashboard, .none:
                DashboardView()
            case .announcements:
                AnnouncementsView()
            case .news:
                NewsView()
            case .publish:
                PublishView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkbenchStore())
}

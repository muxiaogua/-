//
//  SidebarView.swift
//  团队工作台
//

import SwiftUI

public struct SidebarView: View {
    @EnvironmentObject var store: WorkbenchStore
    
    public init() {}
    
    public var body: some View {
        List(AppNavigationItem.allCases, id: \.self, selection: $store.selectedNavigation) { item in
            HStack(spacing: 10) {
                Image(systemName: item.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(colorForItem(item))
                    .frame(width: 20)
                
                Text(item.rawValue)
                    .font(.system(size: 13, weight: store.selectedNavigation == item ? .semibold : .regular))
                
                Spacer()
                
                if item == .announcements && store.unacknowledgedCount > 0 {
                    Text("\(store.unacknowledgedCount)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
            .tag(item)
        }
        .listStyle(.sidebar)
        .navigationTitle("团队工作台")
    }
    
    private func colorForItem(_ item: AppNavigationItem) -> Color {
        switch item {
        case .dashboard: return .blue
        case .announcements: return .red
        case .teamShifts: return .indigo
        case .shifts: return .purple
        case .leaveRequest: return .orange
        case .myStats: return .teal
        case .news: return .green
        case .npiQuery: return .teal
        case .rccFaqNpi: return .orange
        case .faq: return .blue
        case .priceQuery: return .yellow
        case .caseAssistance: return .pink
        case .sharedKnowledge: return .brown
        case .luckyWheel: return .red
        case .dateCalculator: return .cyan
        case .mindRetreat: return .teal
        case .publish: return .orange
        case .settings: return .gray
        }
    }
}

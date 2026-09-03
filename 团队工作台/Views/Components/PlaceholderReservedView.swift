//
//  PlaceholderReservedView.swift
//  团队工作台
//
//

import SwiftUI

public struct PlaceholderReservedView: View {
    public let title: String
    public let icon: String
    public let subtitle: String
    
    public init(
        title: String,
        icon: String,
        subtitle: String = "该板块正在规划与建设中，暂未开放。不预设任何模拟数据，敬请期待！"
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 11))
                Text("功能预留 · 即将上线")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

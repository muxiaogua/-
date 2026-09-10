//
//  AppUpdateSheetView.swift
//  团队工作台
//

import SwiftUI
import AppKit

public struct AppUpdateSheetView: View {
    @ObservedObject var updater = AppUpdateService.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 52, height: 52)
                        .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 3)
                    
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("发现团队工作台新版本")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("v\(updater.latestVersion)")
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                    
                    Text("当前版本 \(updater.currentVersion) · 建议立即升级以获得最新功能与修复")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !updater.isDownloading {
                    Button(action: {
                        updater.showUpdateSheet = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // Release Notes Content
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("更新日志")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if !updater.releaseTitle.isEmpty {
                            Text(updater.releaseTitle)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Text(updater.releaseNotes)
                            .font(.system(size: 12.5))
                            .lineSpacing(4)
                            .foregroundColor(.primary.opacity(0.85))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                }
                .frame(maxHeight: 180)
                .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            // Download Progress / Error Notification
            if updater.isDownloading {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: updater.downloadProgress)
                        .progressViewStyle(.linear)
                    
                    Text(updater.downloadStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            } else if let error = updater.updateError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 11.5))
                        .foregroundColor(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
            }
            
            Divider()
            
            // Footer Action Buttons
            HStack(spacing: 12) {
                Spacer()
                
                if updater.isDownloading {
                    Button("取消下载") {
                        updater.cancelDownload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                } else {
                    Button("稍后提醒") {
                        updater.showUpdateSheet = false
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.regular)
                    
                    Button(action: {
                        updater.startDownloadAndInstall()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("立即更新并重启")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.regular)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    AppUpdateSheetView()
}

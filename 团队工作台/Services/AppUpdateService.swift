//
//  AppUpdateService.swift
//  团队工作台
//

import Foundation
import SwiftUI
import AppKit
import Combine

public struct GitHubReleaseInfo: Codable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String
    public let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

public struct GitHubAsset: Codable {
    public let name: String
    public let browserDownloadUrl: String
    public let size: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

@MainActor
public class AppUpdateService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = AppUpdateService()
    
    public let repoOwner = "muxiaogua"
    public let repoName = "-"
    
    @Published public var isChecking: Bool = false
    @Published public var updateAvailable: Bool = false
    @Published public var latestVersion: String = ""
    @Published public var releaseTitle: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var releaseURL: URL? = nil
    @Published public var downloadAssetURL: URL? = nil
    
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadStatusMessage: String = ""
    @Published public var updateError: String? = nil
    
    @Published public var showUpdateSheet: Bool = false
    @Published public var hasCheckedOnce: Bool = false
    
    private var downloadTask: URLSessionDownloadTask?
    private var session: URLSession?
    
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    public var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }
    
    // MARK: - Check for Updates
    
    public func checkForUpdates(isUserInitiated: Bool = false) {
        guard !isChecking && !isDownloading else { return }
        
        isChecking = true
        updateError = nil
        
        let apiURLString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: apiURLString) else {
            isChecking = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("TeamWorkbench-App/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isChecking = false
                self.hasCheckedOnce = true
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    // No release published yet
                    if isUserInitiated {
                        self.updateError = "当前云端暂未发布新版本（已是最新状态）。"
                    }
                    return
                }
                
                if let error = error {
                    if isUserInitiated {
                        self.updateError = "检查更新失败：\(error.localizedDescription)"
                    }
                    return
                }
                
                guard let data = data else {
                    if isUserInitiated {
                        self.updateError = "无法获取服务器版本响应"
                    }
                    return
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
                    let remoteVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                    
                    self.latestVersion = remoteVersion
                    self.releaseTitle = release.name ?? "新版本 \(remoteVersion)"
                    self.releaseNotes = release.body ?? "包含稳定性提升与功能改进。"
                    self.releaseURL = URL(string: release.htmlUrl)
                    
                    // Look for a .zip asset
                    if let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) {
                        self.downloadAssetURL = URL(string: zipAsset.browserDownloadUrl)
                    } else if let firstAsset = release.assets.first {
                        self.downloadAssetURL = URL(string: firstAsset.browserDownloadUrl)
                    } else {
                        self.downloadAssetURL = nil
                    }
                    
                    if self.isVersion(remoteVersion, newerThan: self.currentVersion) {
                        self.updateAvailable = true
                        self.showUpdateSheet = true
                    } else {
                        self.updateAvailable = false
                        if isUserInitiated {
                            self.downloadStatusMessage = "当前已是最新版本 (\(self.currentVersion))"
                        }
                    }
                } catch {
                    if isUserInitiated {
                        self.updateError = "解析版本信息失败：\(error.localizedDescription)"
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Version Comparison
    
    private func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let clean1 = v1.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
        let clean2 = v2.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
        
        let count = max(clean1.count, clean2.count)
        for i in 0..<count {
            let num1 = i < clean1.count ? (Int(clean1[i]) ?? 0) : 0
            let num2 = i < clean2.count ? (Int(clean2[i]) ?? 0) : 0
            if num1 > num2 { return true }
            if num1 < num2 { return false }
        }
        return false
    }
    
    // MARK: - Download & In-Place Update
    
    public func startDownloadAndInstall() {
        guard let url = downloadAssetURL else {
            // Fallback to browser
            if let releaseURL = releaseURL {
                NSWorkspace.shared.open(releaseURL)
            }
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        downloadStatusMessage = "正在连接并下载最新安装包..."
        updateError = nil
        
        var request = URLRequest(url: url)
        request.setValue("TeamWorkbench-App/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        downloadTask = session?.downloadTask(with: request)
        downloadTask?.resume()
    }
    
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0.0
        downloadStatusMessage = ""
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0.0
        let percent = Int(progress * 100)
        let mbDownloaded = Double(totalBytesWritten) / (1024 * 1024)
        let mbTotal = Double(totalBytesExpectedToWrite) / (1024 * 1024)
        
        Task { @MainActor in
            self.downloadProgress = progress
            if totalBytesExpectedToWrite > 0 {
                self.downloadStatusMessage = String(format: "正在下载：%.1f MB / %.1f MB (%d%%)", mbDownloaded, mbTotal, percent)
            } else {
                self.downloadStatusMessage = String(format: "已下载：%.1f MB...", mbDownloaded)
            }
        }
    }
    
    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        Task { @MainActor in
            self.downloadStatusMessage = "下载完成，正在解压安装..."
            self.performInstallation(from: location)
        }
    }
    
    public nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error, (error as NSError).code != NSURLErrorCancelled {
            Task { @MainActor in
                self.isDownloading = false
                self.updateError = "下载出现异常：\(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Installation & Restart Script
    
    private func performInstallation(from tempZipURL: URL) {
        let fileManager = FileManager.default
        let extractDir = fileManager.temporaryDirectory.appendingPathComponent("TeamWorkbenchUpdate_\(UUID().uuidString)")
        
        do {
            try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
            let localZip = extractDir.appendingPathComponent("update.zip")
            try fileManager.copyItem(at: tempZipURL, to: localZip)
            
            // Unpack using /usr/bin/ditto to preserve macOS metadata and quarantine flags
            let ditto = Process()
            ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            ditto.arguments = ["-xk", localZip.path, extractDir.path]
            try ditto.run()
            ditto.waitUntilExit()
            
            // Find .app inside extractDir
            var foundAppURL: URL? = nil
            if let items = try? fileManager.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil) {
                for item in items where item.pathExtension == "app" {
                    foundAppURL = item
                    break
                }
            }
            
            guard let newAppURL = foundAppURL else {
                self.isDownloading = false
                self.updateError = "解压完成，但在压缩包内未找到 .app 应用程序文件。建议前往网页手动下载。"
                return
            }
            
            // Current running app location
            let currentAppURL = Bundle.main.bundleURL
            let currentAppPath = currentAppURL.path
            let newAppPath = newAppURL.path
            
            self.downloadStatusMessage = "准备就绪，即将无缝重启应用..."
            
            // Run detached bash script to wait for current PID to exit, then replace & reopen
            let pid = ProcessInfo.processInfo.processIdentifier
            let script = """
            while kill -0 \(pid) 2>/dev/null; do
                sleep 0.2
            done
            rm -rf "\(currentAppPath)"
            ditto "\(newAppPath)" "\(currentAppPath)"
            rm -rf "\(extractDir.path)"
            open "\(currentAppPath)"
            """
            
            let updateScriptURL = extractDir.appendingPathComponent("relaunch.sh")
            try script.write(to: updateScriptURL, atomically: true, encoding: .utf8)
            
            let chmod = Process()
            chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmod.arguments = ["+x", updateScriptURL.path]
            try chmod.run()
            chmod.waitUntilExit()
            
            let relauncher = Process()
            relauncher.executableURL = URL(fileURLWithPath: "/bin/bash")
            relauncher.arguments = [updateScriptURL.path]
            try relauncher.run()
            
            // Terminate current app cleanly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        } catch {
            self.isDownloading = false
            self.updateError = "安装过程发生错误：\(error.localizedDescription)。建议前往 GitHub 手动下载。"
        }
    }
}

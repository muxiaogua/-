//
//  SharedFolderSyncService.swift
//  团队工作台
//

import Foundation
import AppKit
import Combine

public struct SharedAckRecord: Codable, Identifiable {
    public var id: UUID
    public var announcementId: UUID
    public var memberName: String
    public var department: String
    public var acknowledgedAt: Date
    
    public init(
        id: UUID = UUID(),
        announcementId: UUID,
        memberName: String,
        department: String = "",
        acknowledgedAt: Date = Date()
    ) {
        self.id = id
        self.announcementId = announcementId
        self.memberName = memberName
        self.department = department
        self.acknowledgedAt = acknowledgedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        announcementId = try container.decode(UUID.self, forKey: .announcementId)
        memberName = try container.decode(String.self, forKey: .memberName)
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        acknowledgedAt = try container.decode(Date.self, forKey: .acknowledgedAt)
    }
}

public struct SharedCommentRecord: Codable, Identifiable {
    public var id: UUID
    public var articleId: UUID
    public var comment: NewsComment
    
    public init(id: UUID = UUID(), articleId: UUID, comment: NewsComment) {
        self.id = id
        self.articleId = articleId
        self.comment = comment
    }
}

final public class SharedFolderSyncService: NSObject, ObservableObject, NSFilePresenter, @unchecked Sendable {
    public static let shared = SharedFolderSyncService()
    
    private let bookmarkKey = "workbench_shared_folder_bookmark_v3"
    private let pathKey = "workbench_shared_folder_path_v3"
    private let stateLock = NSLock()
    private var _internalFolderURL: URL?
    
    @Published public var sharedFolderURL: URL?
    @Published public var sharedFolderPath: String?
    @Published public var isConnected: Bool = false
    @Published public var lastSyncDate: Date?
    @Published public var syncMessage: String?
    
    private let filePresenterQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "com.workbench.sharedfolder.presenter"
        return q
    }()
    
    public var presentedItemURL: URL? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _internalFolderURL
    }
    
    public var presentedItemOperationQueue: OperationQueue {
        filePresenterQueue
    }
    
    public override init() {
        super.init()
        restoreSavedBookmark()
    }
    
    public func selectSharedFolder(completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "选择团队共享文件夹（如 iCloud 团队工作台数据）"
        panel.message = "请选择由您或组长在 iCloud Drive / 访达中创建并共享的团队工作台数据文件夹。"
        panel.prompt = "选定并开启全员同步"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        panel.begin { [weak self] result in
            guard let self = self else { return }
            if result == .OK, let url = panel.url {
                self.bindFolder(url: url)
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    public func bindFolder(url: URL) {
        NSFileCoordinator.removeFilePresenter(self)
        
        _ = url.startAccessingSecurityScopedResource()
        
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        }
        UserDefaults.standard.set(url.path, forKey: pathKey)
        
        stateLock.lock()
        self._internalFolderURL = url
        stateLock.unlock()
        
        DispatchQueue.main.async {
            self.sharedFolderURL = url
            self.sharedFolderPath = url.path
            self.isConnected = true
            self.lastSyncDate = Date()
            self.syncMessage = "已连接团队共享文件夹「\(url.lastPathComponent)」"
        }
        
        createSubdirectoriesIfNeeded(at: url)
        NSFileCoordinator.addFilePresenter(self)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .sharedFolderDataDidUpdate, object: nil)
        }
    }
    
    public func disconnect() {
        NSFileCoordinator.removeFilePresenter(self)
        
        stateLock.lock()
        let oldURL = _internalFolderURL
        _internalFolderURL = nil
        stateLock.unlock()
        
        if let url = oldURL {
            url.stopAccessingSecurityScopedResource()
        }
        
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: pathKey)
        
        DispatchQueue.main.async {
            self.sharedFolderURL = nil
            self.sharedFolderPath = nil
            self.isConnected = false
            self.syncMessage = "已切换回单机本地存储模式"
        }
    }
    
    public func openInFinder() {
        if let url = presentedItemURL {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
        }
    }
    
    private func restoreSavedBookmark() {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
            if let path = UserDefaults.standard.string(forKey: pathKey) {
                let url = URL(fileURLWithPath: path)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    bindFolder(url: url)
                }
            }
            return
        }
        
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            if isStale {
                if let newBookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    UserDefaults.standard.set(newBookmark, forKey: bookmarkKey)
                }
            }
            bindFolder(url: url)
        }
    }
    
    private func createSubdirectoriesIfNeeded(at baseURL: URL) {
        let fileManager = FileManager.default
        let subdirs = ["announcements", "acknowledgments", "news", "comments", "faq", "roster"]
        for sub in subdirs {
            let subURL = baseURL.appendingPathComponent(sub, isDirectory: true)
            if !fileManager.fileExists(atPath: subURL.path) {
                try? fileManager.createDirectory(at: subURL, withIntermediateDirectories: true)
            }
        }
    }
    
    // NSFilePresenter listener: triggered when iCloud downloads modifications from teammates
    public func presentedSubitemDidChange(at url: URL) {
        DispatchQueue.main.async {
            self.lastSyncDate = Date()
            NotificationCenter.default.post(name: .sharedFolderDataDidUpdate, object: nil)
        }
    }
}

public extension Notification.Name {
    static let sharedFolderDataDidUpdate = Notification.Name("workbench_shared_folder_did_update")
}

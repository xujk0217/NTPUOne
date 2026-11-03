import Foundation
import CoreData
import Combine

/// One store and one context for the App. Failures never delete or replace user data.
final class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager(storeURLProvider: {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.NTPUOne.NextCourseWidget")?
            .appendingPathComponent("shared.sqlite")
    })

    let persistentContainer: NSPersistentCloudKitContainer
    @Published private(set) var isReady = false
    @Published private(set) var loadError: String?
    @Published var operationError: String?
    private let storeURLProvider: (() -> URL?)?
    private let cloudSyncEnabled: Bool

    convenience init(storeURLProvider: @escaping () -> URL?) {
        self.init(storeURL: storeURLProvider(), storeURLProvider: storeURLProvider)
    }

    init(storeURL: URL?, model: NSManagedObjectModel? = nil, cloudSyncEnabled: Bool = true,
         storeURLProvider: (() -> URL?)? = nil) {
        self.storeURLProvider = storeURLProvider
        self.cloudSyncEnabled = cloudSyncEnabled
        if let model {
            persistentContainer = NSPersistentCloudKitContainer(name: "CourseModel", managedObjectModel: model)
        } else {
            persistentContainer = NSPersistentCloudKitContainer(name: "CourseModel")
        }
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        guard let storeURL else {
            persistentContainer.persistentStoreDescriptions = []
            loadError = "無法存取共用資料空間。請確認裝置儲存空間及 App 權限，稍後再試。"
            return
        }
        configureStore(at: storeURL)
        retryLoading()
    }

    private func configureStore(at storeURL: URL) {
        let description = NSPersistentStoreDescription(url: storeURL)
        // Finish loading before any view model fetches or schedules notifications.
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        if cloudSyncEnabled {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.xujk.NTPUOne")
        }
        persistentContainer.persistentStoreDescriptions = [description]
    }

    func retryLoading() {
        guard !isReady else { return }
        if persistentContainer.persistentStoreDescriptions.first?.url == nil, let url = storeURLProvider?() {
            configureStore(at: url)
        }
        guard persistentContainer.persistentStoreDescriptions.first?.url != nil else {
            loadError = "無法存取共用資料空間。請確認裝置儲存空間及 App 權限，稍後再試。"
            return
        }
        loadError = nil
        persistentContainer.loadPersistentStores { [self] _, error in
            if let error {
                loadError = "無法開啟課表與備忘錄資料。原始資料已保留，請確認儲存空間後重試。\n\(error.localizedDescription)"
            } else {
                isReady = true
                loadError = nil
            }
        }
    }

    @discardableResult
    func saveContext(_ context: NSManagedObjectContext? = nil) -> Bool {
        let context = context ?? persistentContainer.viewContext
        var success = true
        context.performAndWait {
            guard context.hasChanges else { return }
            do {
                try context.save()
            } catch {
                success = false
                reportOperationError(error)
                // Keep pending changes so the user can retry; do not rollback silently.
            }
        }
        if success {
            if Thread.isMainThread { operationError = nil }
            else { DispatchQueue.main.async { self.operationError = nil } }
        }
        return success
    }

    func reportOperationError(_ error: Error) {
        let message = "變更尚未儲存，請確認儲存空間後重試。關閉 App 可能會遺失本次未儲存的變更。\n\(error.localizedDescription)"
        if Thread.isMainThread {
            operationError = message
        } else {
            DispatchQueue.main.async { self.operationError = message }
        }
    }
}

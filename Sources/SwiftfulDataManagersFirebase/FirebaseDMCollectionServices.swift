//
//  FirebaseDMCollectionServices.swift
//  SwiftfulDataManagersFirebase
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation
import SwiftfulDataManagers
import IdentifiableByString

/// Combined services for CollectionManagerSync with Firebase remote and SwiftData local storage
@MainActor
public struct FirebaseDMCollectionServices<T: DMProtocol & Codable & StringIdentifiable>: DMCollectionServices {
    public let remote: any RemoteCollectionService<T>
    public let local: any LocalCollectionPersistence<T>

    /// Initialize with a static collection path
    /// - Parameters:
    ///   - collectionPath: The Firestore collection path (e.g., "products")
    ///   - managerKey: Unique key for SwiftData local persistence
    public init(collectionPath: String, managerKey: String) {
        self.remote = FirebaseRemoteCollectionService<T>(collectionPath: collectionPath)
        self.local = SwiftDataCollectionPersistence<T>(managerKey: managerKey)
    }

    /// Initialize with a dynamic collection path closure
    /// - Parameters:
    ///   - collectionPath: A closure that returns the Firestore collection path, or nil if not available.
    ///     Useful for paths that depend on runtime values like user IDs.
    ///     Example: `{ AuthService.shared.currentUserId.map { "users/\($0)/favorites" } }`
    ///   - managerKey: Unique key for SwiftData local persistence
    public init(collectionPath: @escaping () -> String?, managerKey: String) {
        self.remote = FirebaseRemoteCollectionService<T>(collectionPath: collectionPath)
        self.local = SwiftDataCollectionPersistence<T>(managerKey: managerKey)
    }
}

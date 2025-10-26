//
//  FirebaseDMDocumentServices.swift
//  SwiftfulDataManagersFirebase
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation
import SwiftfulDataManagers
import IdentifiableByString

/// Combined services for DocumentManagerSync with Firebase remote and FileManager local storage
@MainActor
public struct FirebaseDMDocumentServices<T: DMProtocol & Codable & StringIdentifiable>: DMDocumentServices {
    public let remote: any RemoteDocumentService<T>
    public let local: any LocalDocumentPersistence<T>

    /// Initialize with a static collection path
    /// - Parameter collectionPath: The Firestore collection path (e.g., "users")
    public init(collectionPath: String) {
        self.remote = FirebaseRemoteDocumentService<T>(collectionPath: collectionPath)
        self.local = FileManagerDocumentPersistence<T>()
    }

    /// Initialize with a dynamic collection path closure
    /// - Parameter collectionPath: A closure that returns the Firestore collection path, or nil if not available.
    ///   Useful for paths that depend on runtime values like user IDs.
    ///   Example: `{ AuthService.shared.currentUserId.map { "users/\($0)/favorites" } }`
    public init(collectionPath: @escaping () -> String?) {
        self.remote = FirebaseRemoteDocumentService<T>(collectionPath: collectionPath)
        self.local = FileManagerDocumentPersistence<T>()
    }
}

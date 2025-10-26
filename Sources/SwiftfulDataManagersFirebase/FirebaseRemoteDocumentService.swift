//
//  FirebaseRemoteDocumentService.swift
//  SwiftfulDataManagersFirebase
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation
import FirebaseFirestore
import SwiftfulFirestore
import SwiftfulDataManagers
import IdentifiableByString

public enum FirebaseServiceError: Error {
    case collectionPathNotAvailable
}

@MainActor
public struct FirebaseRemoteDocumentService<T: DMProtocol & Codable & StringIdentifiable>: RemoteDocumentService {

    private let collectionPath: () -> String?

    private var documentCollection: CollectionReference {
        get throws {
            guard let path = collectionPath() else {
                throw FirebaseServiceError.collectionPathNotAvailable
            }
            return Firestore.firestore().collection(path)
        }
    }

    /// Initialize the Firebase Remote Document Service with a static path
    /// - Parameter collectionPath: The Firestore collection path where documents are stored.
    ///   Can be a simple collection name (e.g., "users") or a nested path (e.g., "users/data/favorites").
    ///   Example: "users" → "users/{documentId}"
    ///   Example: "users/user123/favorites" → "users/user123/favorites/{documentId}"
    public init(collectionPath: String) {
        self.collectionPath = { collectionPath }
    }

    /// Initialize the Firebase Remote Document Service with a dynamic path closure
    /// - Parameter collectionPath: A closure that returns the Firestore collection path, or nil if not available.
    ///   Useful for paths that depend on runtime values like user IDs.
    ///   Returns nil when the path is not yet available (e.g., before login).
    ///   Example: `{ AuthService.shared.currentUserId.map { "users/\($0)/favorites" } }`
    public init(collectionPath: @escaping () -> String?) {
        self.collectionPath = collectionPath
    }

    // MARK: - RemoteDocumentService Implementation

    public func getDocument(id: String) async throws -> T {
        try await documentCollection.getDocument(id: id)
    }

    public func saveDocument(_ model: T) async throws {
        try documentCollection.document(model.id).setData(from: model, merge: true)
    }

    public func updateDocument(id: String, data: [String: any DMCodableSendable]) async throws {
        // Convert DMCodableSendable dictionary to plain dictionary for Firestore
        var firestoreData: [String: Any] = [:]
        for (key, value) in data {
            firestoreData[key] = value
        }
        try await documentCollection.document(id).updateData(firestoreData)
    }

    public func streamDocument(id: String) -> AsyncThrowingStream<T?, Error> {
        do {
            return try documentCollection.streamDocument(id: id)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }

    public func deleteDocument(id: String) async throws {
        try await documentCollection.document(id).delete()
    }
}
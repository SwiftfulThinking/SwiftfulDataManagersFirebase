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

@MainActor
public struct FirebaseRemoteDocumentService<T: DataModelProtocol>: RemoteDocumentService {

    private let collectionPath: String

    private var documentCollection: CollectionReference {
        Firestore.firestore().collection(collectionPath)
    }

    /// Initialize the Firebase Remote Document Service
    /// - Parameter collectionPath: The Firestore collection path where documents are stored.
    ///   Can be a simple collection name (e.g., "users") or a nested path (e.g., "users/data/favorites").
    ///   Example: "users" → "users/{documentId}"
    ///   Example: "users/user123/favorites" → "users/user123/favorites/{documentId}"
    public init(collectionPath: String) {
        self.collectionPath = collectionPath
    }

    // MARK: - RemoteDocumentService Implementation

    public func getDocument(id: String) async throws -> T {
        try await documentCollection.getDocument(id: id)
    }

    public func saveDocument(_ model: T) async throws {
        try documentCollection.document(model.id).setData(from: model, merge: true)
    }

    public func updateDocument(id: String, data: [String: any Sendable]) async throws {
        try await documentCollection.updateDocument(id: id, dict: data)
    }

    public func streamDocument(id: String) -> AsyncThrowingStream<T?, Error> {
        documentCollection.streamDocument(id: id)
    }

    public func deleteDocument(id: String) async throws {
        try await documentCollection.document(id).delete()
    }
}

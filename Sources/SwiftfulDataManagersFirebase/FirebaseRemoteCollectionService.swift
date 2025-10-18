//
//  FirebaseRemoteCollectionService.swift
//  SwiftfulDataManagersFirebase
//
//  Created by Nick Sarno on 1/17/25.
//

import Foundation
import FirebaseFirestore
import SwiftfulFirestore
import SwiftfulDataManagers

@MainActor
public class FirebaseRemoteCollectionService<T: DataModelProtocol>: RemoteCollectionService {

    private let collectionPath: String
    private var listenerTask: Task<Void, Never>?

    private var documentCollection: CollectionReference {
        Firestore.firestore().collection(collectionPath)
    }

    /// Initialize the Firebase Remote Collection Service
    /// - Parameter collectionPath: The Firestore collection path where documents are stored.
    ///   Can be a simple collection name (e.g., "users") or a nested path (e.g., "users/data/favorites").
    ///   Example: "users" → "users/{documentId}"
    ///   Example: "users/user123/favorites" → "users/user123/favorites/{documentId}"
    public init(collectionPath: String) {
        self.collectionPath = collectionPath
    }

    // MARK: - RemoteCollectionService Implementation

    public func getCollection() async throws -> [T] {
        try await documentCollection.getAllDocuments()
    }

    public func getDocument(id: String) async throws -> T {
        try await documentCollection.getDocument(id: id)
    }

    public func saveDocument(_ model: T) async throws {
        try documentCollection.document(model.id).setData(from: model, merge: true)
    }

    public func updateDocument(id: String, data: [String: any Sendable]) async throws {
        try await documentCollection.updateDocument(id: id, dict: data)
    }

    public func streamCollectionUpdates() -> (
        updates: AsyncThrowingStream<T, Error>,
        deletions: AsyncThrowingStream<String, Error>
    ) {
        var updatesCont: AsyncThrowingStream<T, Error>.Continuation?
        var deletionsCont: AsyncThrowingStream<String, Error>.Continuation?

        let updates = AsyncThrowingStream<T, Error> { continuation in
            updatesCont = continuation

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.listenerTask?.cancel()
                }
            }
        }

        let deletions = AsyncThrowingStream<String, Error> { continuation in
            deletionsCont = continuation

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.listenerTask?.cancel()
                }
            }
        }

        // Start the shared Firestore listener
        listenerTask = Task {
            do {
                let collection = documentCollection
                for try await change in collection.streamAllDocumentChanges() as AsyncThrowingStream<SwiftfulFirestore.DocumentChange<T>, Error> {
                    switch change.type {
                    case .added, .modified:
                        updatesCont?.yield(change.document)
                    case .removed:
                        deletionsCont?.yield(change.document.id)
                    }
                }
            } catch {
                updatesCont?.finish(throwing: error)
                deletionsCont?.finish(throwing: error)
            }
        }

        return (updates, deletions)
    }

    public func deleteDocument(id: String) async throws {
        try await documentCollection.document(id).delete()
    }

    public func getDocuments(where filters: [String: any Sendable]) async throws -> [T] {
        var query: Query = documentCollection

        // Apply all filters as equality queries
        for (field, value) in filters {
            query = query.whereField(field, isEqualTo: value)
        }

        return try await query.getAllDocuments()
    }
}

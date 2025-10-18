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

    public func streamCollection() -> AsyncThrowingStream<[T], Error> {
        var continuation: AsyncThrowingStream<[T], Error>.Continuation?

        let stream = AsyncThrowingStream<[T], Error> { cont in
            continuation = cont

            cont.onTermination = { @Sendable _ in
                Task {
                    await self.listenerTask?.cancel()
                }
            }
        }

        // Start the Firestore listener
        listenerTask = Task {
            do {
                for try await _ in documentCollection.streamAllDocumentChanges() as AsyncThrowingStream<SwiftfulFirestore.DocumentChange<T>, Error> {
                    // Fetch entire collection on each change
                    let collection = try await documentCollection.getAllDocuments() as [T]
                    continuation?.yield(collection)
                }
            } catch {
                continuation?.finish(throwing: error)
            }
        }

        return stream
    }

    public func deleteDocument(id: String) async throws {
        try await documentCollection.document(id).delete()
    }
}

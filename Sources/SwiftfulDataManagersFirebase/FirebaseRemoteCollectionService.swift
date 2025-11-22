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
import IdentifiableByString

@MainActor
public class FirebaseRemoteCollectionService<T: DMProtocol & Codable & StringIdentifiable>: RemoteCollectionService {

    private let collectionPath: () -> String?
    private var listenerTask: Task<Void, Never>?

    private var documentCollection: CollectionReference {
        get throws {
            guard let path = collectionPath() else {
                throw FirebaseServiceError.collectionPathNotAvailable
            }
            return Firestore.firestore().collection(path)
        }
    }

    /// Initialize the Firebase Remote Collection Service
    /// - Parameter collectionPath: A closure that returns the Firestore collection path, or nil if not available.
    ///   For static paths: `{ "products" }`
    ///   For dynamic paths: `{ AuthService.shared.currentUserId.map { "users/\($0)/favorites" } }`
    ///   Returns nil when the path is not yet available (e.g., before login).
    ///   Operations will throw `FirebaseServiceError.collectionPathNotAvailable` if the path is nil.
    public init(collectionPath: @escaping () -> String?) {
        self.collectionPath = collectionPath
    }

    // MARK: - RemoteCollectionService Implementation

    public func getCollection() async throws -> [T] {
        try await documentCollection.getAllDocuments()
    }

    public func getDocument(id: String) async throws -> T {
        try await documentCollection.getDocument(id: id)
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
                let collection = try documentCollection
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

    public func getDocuments(query: QueryBuilder) async throws -> [T] {
        var firestoreQuery: Query = try documentCollection

        // Apply all filters from QueryBuilder
        for filter in query.getFilters() {
            switch filter.operator {
            case .isEqualTo:
                firestoreQuery = firestoreQuery.whereField(filter.field, isEqualTo: filter.value)
            case .isNotEqualTo:
                firestoreQuery = firestoreQuery.whereField(filter.field, isNotEqualTo: filter.value)
            case .isGreaterThan:
                firestoreQuery = firestoreQuery.whereField(filter.field, isGreaterThan: filter.value)
            case .isLessThan:
                firestoreQuery = firestoreQuery.whereField(filter.field, isLessThan: filter.value)
            case .isGreaterThanOrEqualTo:
                firestoreQuery = firestoreQuery.whereField(filter.field, isGreaterThanOrEqualTo: filter.value)
            case .isLessThanOrEqualTo:
                firestoreQuery = firestoreQuery.whereField(filter.field, isLessThanOrEqualTo: filter.value)
            case .arrayContains:
                firestoreQuery = firestoreQuery.whereField(filter.field, arrayContains: filter.value)
            case .in:
                if let array = filter.value as? [Any] {
                    firestoreQuery = firestoreQuery.whereField(filter.field, in: array)
                }
            case .notIn:
                if let array = filter.value as? [Any] {
                    firestoreQuery = firestoreQuery.whereField(filter.field, notIn: array)
                }
            case .arrayContainsAny:
                if let array = filter.value as? [Any] {
                    firestoreQuery = firestoreQuery.whereField(filter.field, arrayContainsAny: array)
                }
            }
        }

        return try await firestoreQuery.getAllDocuments()
    }
}
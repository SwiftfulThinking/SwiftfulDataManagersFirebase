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
public class FirebaseRemoteCollectionService<T: DataSyncModelProtocol>: RemoteCollectionService {

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

    public func streamCollection() -> AsyncThrowingStream<[T], Error> {
        do {
            return try documentCollection.streamAllDocuments()
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }

    public func streamCollection(query: QueryBuilder) -> AsyncThrowingStream<[T], Error> {
        do {
            let firestoreQuery = try buildFirestoreQuery(from: query)
            return firestoreQuery.streamAllDocuments()
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }

    public func deleteDocument(id: String) async throws {
        try await documentCollection.document(id).delete()
    }

    public func getDocuments(query: QueryBuilder) async throws -> [T] {
        let firestoreQuery = try buildFirestoreQuery(from: query)
        return try await firestoreQuery.getAllDocuments()
    }

    public func streamCollectionUpdates(query: QueryBuilder) -> (
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

        // Start the shared Firestore listener on the filtered query
        listenerTask = Task {
            do {
                let firestoreQuery = try buildFirestoreQuery(from: query)
                for try await change in firestoreQuery.streamAllDocumentChanges() as AsyncThrowingStream<SwiftfulFirestore.DocumentChange<T>, Error> {
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

    // MARK: - Private

    private func buildFirestoreQuery(from query: QueryBuilder) throws -> Query {
        var firestoreQuery: Query = try documentCollection

        for operation in query.getOperations() {
            switch operation {
            case .filter(let filter):
                firestoreQuery = applyFilter(filter, to: firestoreQuery)
            case .order(let order):
                firestoreQuery = firestoreQuery.order(by: order.field, descending: order.descending)
            case .limit(let value):
                firestoreQuery = firestoreQuery.limit(to: value)
            case .limitToLast(let value):
                firestoreQuery = firestoreQuery.limit(toLast: value)
            case .startAt(let cursor):
                firestoreQuery = firestoreQuery.start(at: cursor.values)
            case .startAfter(let cursor):
                firestoreQuery = firestoreQuery.start(after: cursor.values)
            case .endAt(let cursor):
                firestoreQuery = firestoreQuery.end(at: cursor.values)
            case .endBefore(let cursor):
                firestoreQuery = firestoreQuery.end(before: cursor.values)
            }
        }

        return firestoreQuery
    }

    private func applyFilter(_ filter: QueryFilter, to query: Query) -> Query {
        switch filter.operator {
        case .isEqualTo:
            return query.whereField(filter.field, isEqualTo: filter.value)
        case .isNotEqualTo:
            return query.whereField(filter.field, isNotEqualTo: filter.value)
        case .isGreaterThan:
            return query.whereField(filter.field, isGreaterThan: filter.value)
        case .isLessThan:
            return query.whereField(filter.field, isLessThan: filter.value)
        case .isGreaterThanOrEqualTo:
            return query.whereField(filter.field, isGreaterThanOrEqualTo: filter.value)
        case .isLessThanOrEqualTo:
            return query.whereField(filter.field, isLessThanOrEqualTo: filter.value)
        case .arrayContains:
            return query.whereField(filter.field, arrayContains: filter.value)
        case .in:
            if let array = filter.value as? [Any] {
                return query.whereField(filter.field, in: array)
            }
            return query
        case .notIn:
            if let array = filter.value as? [Any] {
                return query.whereField(filter.field, notIn: array)
            }
            return query
        case .arrayContainsAny:
            if let array = filter.value as? [Any] {
                return query.whereField(filter.field, arrayContainsAny: array)
            }
            return query
        }
    }
}

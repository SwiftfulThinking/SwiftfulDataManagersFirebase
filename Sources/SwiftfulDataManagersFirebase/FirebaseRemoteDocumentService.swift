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

    /// Initialize the Firebase Remote Document Service
    /// - Parameter collectionPath: A closure that returns the Firestore collection path, or nil if not available.
    ///   For static paths: `{ "users" }`
    ///   For dynamic paths: `{ AuthService.shared.currentUserId.map { "users/\($0)/favorites" } }`
    ///   Returns nil when the path is not yet available (e.g., before login).
    ///   Operations will throw `FirebaseServiceError.collectionPathNotAvailable` if the path is nil.
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
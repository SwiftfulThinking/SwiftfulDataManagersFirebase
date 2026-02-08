//
//  SwiftfulDataManagersFirebase.swift
//  SwiftfulDataManagersFirebase
//
//  Created by Nick Sarno on 1/17/25.
//

// This is the main module file for SwiftfulDataManagersFirebase.
// Firebase Firestore implementations of RemoteDocumentService and RemoteCollectionService.
//
// Usage:
//
// For DocumentSyncEngine:
// ```swift
// let userSyncEngine = DocumentSyncEngine<UserModel>(
//     remote: FirebaseRemoteDocumentService(collectionPath: { "users" }),
//     managerKey: "user"
// )
// ```
//
// For CollectionSyncEngine:
// ```swift
// let productsSyncEngine = CollectionSyncEngine<Product>(
//     remote: FirebaseRemoteCollectionService(collectionPath: { "products" }),
//     managerKey: "products"
// )
// ```
//
// Dynamic Collection Paths:
// - Static: `{ "users" }` → users/{documentId}
// - Dynamic: `{ "users/\(uid)/favorites" }` → users/{uid}/favorites/{documentId}

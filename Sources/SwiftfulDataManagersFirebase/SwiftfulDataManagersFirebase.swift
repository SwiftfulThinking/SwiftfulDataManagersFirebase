//
//  SwiftfulDataManagersFirebase.swift
//  SwiftfulDataManagersFirebase
//
//  Created by Nick Sarno on 1/17/25.
//

// This is the main module file for SwiftfulDataManagersFirebase.
// Firebase implementations of RemoteDocumentService and RemoteCollectionService.
//
// Usage:
//
// For Document Management:
// ```swift
// let documentService = FirebaseRemoteDocumentService<User>(collectionPath: "users")
// let manager = DocumentManagerSync(remote: documentService, ...)
// ```
//
// For Collection Management:
// ```swift
// let collectionService = FirebaseRemoteCollectionService<Product>(collectionPath: "products")
// let manager = CollectionManagerSync(remote: collectionService, ...)
// ```
//
// Dynamic Collection Paths:
// - Simple: "users" → users/{documentId}
// - Nested: "users/user123/favorites" → users/user123/favorites/{documentId}

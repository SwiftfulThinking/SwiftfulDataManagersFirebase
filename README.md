# Firebase for SwiftfulDataManagers ✅

Add Firebase Firestore support to a Swift application through SwiftfulDataManagers framework.

See documentation in the parent repo: https://github.com/SwiftfulThinking/SwiftfulDataManagers

## Example configuration:

```swift
// Document Manager
#if DEBUG
let documentManager = DocumentManagerSync(
    services: MockDMDocumentServices<UserModel>(),
    configuration: .mock(managerKey: "user")
)
#else
let documentManager = DocumentManagerSync(
    services: FirebaseDMDocumentServices<UserModel>(collectionPath: "users"),
    configuration: DataManagerSyncConfiguration(managerKey: "user")
)
#endif

// Collection Manager
#if DEBUG
let collectionManager = CollectionManagerSync(
    services: MockDMCollectionServices<ProductModel>(),
    configuration: .mock(managerKey: "products")
)
#else
let collectionManager = CollectionManagerSync(
    services: FirebaseDMCollectionServices<ProductModel>(collectionPath: "products"),
    configuration: DataManagerSyncConfiguration(managerKey: "products")
)
#endif

// Async Document Manager
#if DEBUG
let asyncDocManager = DocumentManagerAsync(
    service: MockRemoteDocumentService<UserModel>(),
    configuration: .mock(managerKey: "user")
)
#else
let asyncDocManager = DocumentManagerAsync(
    service: FirebaseRemoteDocumentService<UserModel>(collectionPath: "users"),
    configuration: DataManagerAsyncConfiguration(managerKey: "user")
)
#endif

// Async Collection Manager
#if DEBUG
let asyncCollectionManager = CollectionManagerAsync(
    service: MockRemoteCollectionService<ProductModel>(),
    configuration: .mock(managerKey: "products")
)
#else
let asyncCollectionManager = CollectionManagerAsync(
    service: FirebaseRemoteCollectionService<ProductModel>(collectionPath: "products"),
    configuration: DataManagerAsyncConfiguration(managerKey: "products")
)
#endif
```

## Example actions:

```swift
// Document Manager Sync
try await documentManager.logIn("user_123")
try await documentManager.saveDocument(user)
try await documentManager.updateDocument(data: ["name": "John"])
documentManager.currentDocument
documentManager.logOut()

// Collection Manager Sync
await collectionManager.logIn()
try await collectionManager.saveDocument(product)
try await collectionManager.updateDocument(id: "product_123", data: ["price": 99.99])
collectionManager.getDocument(id: "product_123")
await collectionManager.logOut()

// Document Manager Async
let user = try await asyncDocManager.getDocument(id: "user_123")
try await asyncDocManager.saveDocument(user)
try await asyncDocManager.deleteDocument(id: "user_123")

// Collection Manager Async
let products = try await asyncCollectionManager.getCollection()
try await asyncCollectionManager.saveDocument(product)
let query = QueryBuilder().whereField("category", isEqualTo: "electronics")
let results = try await asyncCollectionManager.getDocuments(query: query)
```

## Dynamic Collection Paths

<details>
<summary> Details (Click to expand) </summary>
<br>

Firebase services support dynamic collection paths for nested documents:

```swift
// Static collection path
let service = FirebaseRemoteDocumentService<UserModel>(
    collectionPath: "users"
)
// Creates: users/{userId}

// Dynamic nested path
let service = FirebaseRemoteDocumentService<FavoriteModel>(
    collectionPath: "users/\(userId)/favorites"
)
// Creates: users/{userId}/favorites/{favoriteId}

// Multiple nesting levels
let service = FirebaseRemoteCollectionService<CommentModel>(
    collectionPath: "posts/\(postId)/comments/\(commentId)/replies"
)
// Creates: posts/{postId}/comments/{commentId}/replies/{replyId}
```

This is useful for:
- User-specific subcollections
- Hierarchical data structures
- Scoped collections per entity

</details>

## Custom Services Implementation

<details>
<summary> Details (Click to expand) </summary>
<br>

Create combined services for sync managers:

```swift
// Document Services
struct FirebaseDMDocumentServices<T: DMProtocol>: DMDocumentServices {
    let remote: any RemoteDocumentService<T>
    let local: any LocalDocumentPersistence<T>

    init(collectionPath: String) {
        self.remote = FirebaseRemoteDocumentService<T>(collectionPath: collectionPath)
        self.local = FileManagerDocumentPersistence<T>()
    }
}

// Collection Services
struct FirebaseDMCollectionServices<T: DMProtocol>: DMCollectionServices {
    let remote: any RemoteCollectionService<T>
    let local: any LocalCollectionPersistence<T>

    init(collectionPath: String, managerKey: String) {
        self.remote = FirebaseRemoteCollectionService<T>(collectionPath: collectionPath)
        self.local = SwiftDataCollectionPersistence<T>(managerKey: managerKey)
    }
}
```

</details>

## Firebase Firestore Setup

<details>
<summary> Details (Click to expand) </summary>
<br>

Firebase docs: https://firebase.google.com/docs/firestore

### 1. Enable Firestore in Firebase console
* Firebase Console -> Build -> Firestore Database -> Create Database

### 2. Set Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own documents
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Allow authenticated users to read all products, write if admin
    match /products/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }

    // Add more rules as needed
  }
}
```

### 3. Add Firebase SDK to your project
```swift
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
    .package(url: "https://github.com/SwiftfulThinking/SwiftfulDataManagersFirebase.git", branch: "main")
]
```

### 4. Initialize Firebase in your app
```swift
import Firebase

// In App init or AppDelegate
FirebaseApp.configure()
```

</details>

## Streaming Updates Pattern

<details>
<summary> Details (Click to expand) </summary>
<br>

### Document Streaming
FirebaseRemoteDocumentService provides real-time document updates:
```swift
func streamDocument(id: String) -> AsyncThrowingStream<T?, Error>
```

### Collection Streaming
FirebaseRemoteCollectionService follows the hybrid pattern:
```swift
// 1. Bulk load all documents first
let collection = try await service.getCollection()

// 2. Stream individual updates/deletions
func streamCollectionUpdates() -> (
    updates: AsyncThrowingStream<T, Error>,
    deletions: AsyncThrowingStream<String, Error>
)
```

This pattern:
- Prevents unnecessary full collection re-fetches
- Efficiently handles individual document changes
- Maintains consistency with SwiftfulGamification's ProgressManager

</details>

## Parent Repo

Full documentation and examples: https://github.com/SwiftfulThinking/SwiftfulDataManagers
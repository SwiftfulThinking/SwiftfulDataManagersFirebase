# Firebase for SwiftfulDataManagers ✅

Add Firebase Firestore support to a Swift application through SwiftfulDataManagers framework.

See documentation in the parent repo: https://github.com/SwiftfulThinking/SwiftfulDataManagers

## Example configuration:

```swift
// Async Document Manager - Static path
let asyncDocManager = DocumentManagerAsync(
    service: FirebaseRemoteDocumentService<UserModel>(
        collectionPath: { "users" }
    ),
    configuration: DataManagerAsyncConfiguration(managerKey: "user")
)

// Async Document Manager - Dynamic path
let favoritesManager = DocumentManagerAsync(
    service: FirebaseRemoteDocumentService<FavoriteModel>(
        collectionPath: {
            AuthService.shared.currentUserId.map { "users/\($0)/favorites" }
        }
    ),
    configuration: DataManagerAsyncConfiguration(managerKey: "favorites")
)

// Async Collection Manager - Static path
let asyncCollectionManager = CollectionManagerAsync(
    service: FirebaseRemoteCollectionService<ProductModel>(
        collectionPath: { "products" }
    ),
    configuration: DataManagerAsyncConfiguration(managerKey: "products")
)

// Async Collection Manager - Dynamic path
let userPostsManager = CollectionManagerAsync(
    service: FirebaseRemoteCollectionService<PostModel>(
        collectionPath: {
            AuthService.shared.currentUserId.map { "users/\($0)/posts" }
        }
    ),
    configuration: DataManagerAsyncConfiguration(managerKey: "posts")
)
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

Firebase services use closures for collection paths, supporting both static and dynamic paths:

### Static Paths
```swift
// Simple collection
let service = FirebaseRemoteDocumentService<UserModel>(
    collectionPath: { "users" }
)
// Creates: users/{documentId}

// Nested collection with hardcoded IDs
let service = FirebaseRemoteCollectionService<CommentModel>(
    collectionPath: { "posts/post123/comments" }
)
// Creates: posts/post123/comments/{documentId}
```

### Dynamic Paths
```swift
// Path depends on runtime value (e.g., current user)
@Observable
class AuthService {
    var currentUserId: String?
}

let favoritesManager = DocumentManagerAsync(
    service: FirebaseRemoteDocumentService<FavoriteModel>(
        collectionPath: {
            AuthService.shared.currentUserId.map { "users/\($0)/favorites" }
        }
    ),
    configuration: DataManagerAsyncConfiguration(managerKey: "favorites")
)

// Or using guard statement
let favoritesManager = DocumentManagerAsync(
    service: FirebaseRemoteDocumentService<FavoriteModel>(
        collectionPath: {
            guard let userId = AuthService.shared.currentUserId else {
                return nil
            }
            return "users/\(userId)/favorites"
        }
    ),
    configuration: DataManagerAsyncConfiguration(managerKey: "favorites")
)

// Multiple nesting levels
let repliesManager = CollectionManagerAsync(
    service: FirebaseRemoteCollectionService<ReplyModel>(
        collectionPath: {
            guard let postId = currentPostId,
                  let commentId = currentCommentId else {
                return nil
            }
            return "posts/\(postId)/comments/\(commentId)/replies"
        }
    ),
    configuration: DataManagerAsyncConfiguration(managerKey: "replies")
)
```

**Use cases:**
- User-specific subcollections (favorites, settings, posts)
- Hierarchical data structures (comments, replies)
- Scoped collections per entity
- Manager initialization before authentication

**Error handling:**
When the closure returns `nil`, operations will throw `FirebaseServiceError.collectionPathNotAvailable`. This allows managers to be created before the path is available (e.g., before login), and operations will automatically fail with a clear error until the path becomes available.

</details>

## Custom Service Wrappers (Optional)

<details>
<summary> Details (Click to expand) </summary>
<br>

For sync managers, you may want to create custom service wrappers that combine Firebase remote services with local persistence. Here's how:

### Document Services Wrapper
```swift
struct FirebaseDMDocumentServices<T: DMProtocol & Codable & StringIdentifiable>: DMDocumentServices {
    let remote: any RemoteDocumentService<T>
    let local: any LocalDocumentPersistence<T>

    init(collectionPath: @escaping () -> String?) {
        self.remote = FirebaseRemoteDocumentService<T>(collectionPath: collectionPath)
        self.local = FileManagerDocumentPersistence<T>()
    }
}

// Usage
let manager = DocumentManagerSync(
    services: FirebaseDMDocumentServices<FavoriteModel>(
        collectionPath: {
            AuthService.shared.currentUserId.map { "users/\($0)/favorites" }
        }
    ),
    configuration: DataManagerSyncConfiguration(managerKey: "favorites")
)
```

### Collection Services Wrapper
```swift
struct FirebaseDMCollectionServices<T: DMProtocol & Codable & StringIdentifiable>: DMCollectionServices {
    let remote: any RemoteCollectionService<T>
    let local: any LocalCollectionPersistence<T>

    init(collectionPath: @escaping () -> String?, managerKey: String) {
        self.remote = FirebaseRemoteCollectionService<T>(collectionPath: collectionPath)
        self.local = SwiftDataCollectionPersistence<T>(managerKey: managerKey)
    }
}

// Usage
let manager = CollectionManagerSync(
    services: FirebaseDMCollectionServices<ProductModel>(
        collectionPath: { "products" },
        managerKey: "products"
    ),
    configuration: DataManagerSyncConfiguration(managerKey: "products")
)
```

**Note:** These are optional convenience wrappers. For async managers, use the services directly as shown in the examples above.

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
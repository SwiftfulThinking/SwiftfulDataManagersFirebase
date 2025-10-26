# Firebase for SwiftfulDataManagers ✅

Add Firebase Firestore support to a Swift application through SwiftfulDataManagers framework.

See documentation in the parent repo: https://github.com/SwiftfulThinking/SwiftfulDataManagers

## Example configuration:

```swift
// Document Manager (Sync) - Static path
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

// Document Manager (Sync) - Dynamic path with closure
#if DEBUG
let favoritesManager = DocumentManagerSync(
    services: MockDMDocumentServices<FavoriteModel>(),
    configuration: .mock(managerKey: "favorites")
)
#else
let favoritesManager = DocumentManagerSync(
    services: FirebaseDMDocumentServices<FavoriteModel>(
        collectionPath: {
            AuthService.shared.currentUserId.map { "users/\($0)/favorites" }
        }
    ),
    configuration: DataManagerSyncConfiguration(managerKey: "favorites")
)
#endif

// Collection Manager (Sync) - Static path
#if DEBUG
let collectionManager = CollectionManagerSync(
    services: MockDMCollectionServices<ProductModel>(),
    configuration: .mock(managerKey: "products")
)
#else
let collectionManager = CollectionManagerSync(
    services: FirebaseDMCollectionServices<ProductModel>(
        collectionPath: "products",
        managerKey: "products"
    ),
    configuration: DataManagerSyncConfiguration(managerKey: "products")
)
#endif

// Async Document Manager - Static path
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

// Async Collection Manager - Static path
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

### Static Path (String)
```swift
// Static collection path
let service = FirebaseRemoteDocumentService<UserModel>(
    collectionPath: "users"
)
// Creates: users/{userId}
```

### Dynamic Path with String Interpolation
```swift
// Dynamic nested path - requires userId at initialization
let userId = "user123"
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

### Dynamic Path with Closure (returns String?)
```swift
// Dynamic path closure - resolves at runtime
let favoritesManager = DocumentManagerAsync(
    service: FirebaseRemoteDocumentService<FavoriteModel>(
        collectionPath: {
            AuthService.shared.currentUserId.map { "users/\($0)/favorites" }
        }
    ),
    configuration: DataManagerAsyncConfiguration(managerKey: "favorites")
)
// Returns nil when user is not logged in
// Throws FirebaseServiceError.collectionPathNotAvailable when operations are attempted before login

// Using with optional chaining
@Observable
class AuthService {
    var currentUserId: String?
}

// Manager can be created before userId is available
let manager = DocumentManagerAsync(
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
// Operations will throw error until user logs in and userId is set
```

**Use cases:**
- User-specific subcollections (e.g., favorites, settings)
- Hierarchical data structures (e.g., comments on posts)
- Scoped collections per entity
- Manager initialization before authentication

**Error handling:**
When using closures that return `String?`, operations will throw `FirebaseServiceError.collectionPathNotAvailable` if the path is nil.

</details>

## Provided Service Wrappers

<details>
<summary> Details (Click to expand) </summary>
<br>

The package provides pre-built service wrappers that combine Firebase remote storage with local persistence:

### FirebaseDMDocumentServices
Combines `FirebaseRemoteDocumentService` with `FileManagerDocumentPersistence` for sync document managers.

```swift
// Static path
let services = FirebaseDMDocumentServices<UserModel>(
    collectionPath: "users"
)

// Dynamic path with closure
let services = FirebaseDMDocumentServices<FavoriteModel>(
    collectionPath: {
        AuthService.shared.currentUserId.map { "users/\($0)/favorites" }
    }
)
```

### FirebaseDMCollectionServices
Combines `FirebaseRemoteCollectionService` with `SwiftDataCollectionPersistence` for sync collection managers.

```swift
// Static path
let services = FirebaseDMCollectionServices<ProductModel>(
    collectionPath: "products",
    managerKey: "products"
)

// Dynamic path with closure
let services = FirebaseDMCollectionServices<FavoriteModel>(
    collectionPath: {
        AuthService.shared.currentUserId.map { "users/\($0)/favorites" }
    },
    managerKey: "favorites"
)
```

**Note:** For async managers (`DocumentManagerAsync`, `CollectionManagerAsync`), use the remote services directly:
- `FirebaseRemoteDocumentService`
- `FirebaseRemoteCollectionService`

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
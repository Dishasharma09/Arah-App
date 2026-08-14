<div align="center">
  <img src="assets/images/Arah_logo.png" alt="Arah Logo" width="150"/>
  <h1>Arah App</h1>
  <p>A peer-to-peer student freelancing platform built with Flutter and Firebase. Students can hire talent (Buyer mode), offer skills (Seller mode), or do both seamlessly within the same app.</p>

  <!-- Badges -->
  <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase" alt="Firebase"></a>
  <a href="https://dart.dev/"><img src="https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"></a>
</div>

---

## 🚀 Features

- **Dual-Mode Profiles:** Seamlessly switch between Buyer and Seller modes without needing separate accounts.
- **Task Marketplace:** Buyers can post tasks and sellers can browse a real-time feed of open opportunities.
- **In-App Messaging:** Real-time task-scoped chat for negotiating and clarifying requirements.
- **Order Management:** Track pending and completed tasks, assign tasks to sellers, and manage deliveries.
- **Rating System:** Two-way 5-star rating system to build trust and reputation in the community.
- **Cross-Platform:** Beautiful, responsive UI built with Material 3, supporting Android and iOS.

---

## 🛠 Tech Stack

- **UI Framework:** Flutter (Material 3)
- **State Management:** Provider
- **Authentication:** Firebase Auth
- **Database:** Cloud Firestore
- **Storage:** Firebase Storage
- **Local Cache:** SharedPreferences

---

## 💻 Setup & Installation

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.0.0 or higher)
- [Firebase CLI](https://firebase.google.com/docs/cli) (for backend configuration)

### Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/Maddy1505/Arah-App.git
   cd arah_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new project in the [Firebase Console](https://console.firebase.google.com/).
   - Enable Authentication (Email/Password), Cloud Firestore, and Firebase Storage.
   - Run `flutterfire configure` in the project root to connect your Firebase project.

4. **Run the App**
   ```bash
   flutter run
   ```

---

## 🏗 Architecture Overview

| Layer | Technology |
|-------|------------|
| UI | Flutter (Material 3) |
| State Management | Provider |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| File Storage | Firebase Storage |
| Local Cache | SharedPreferences |

**Key Providers:**
- `UserProvider` — Auth state, profile, mode switching
- `HomeProvider` — Open task feed (real Firestore, excludes own tasks)
- `OrderProvider` — Active/completed orders per role
- `RequestProvider` — Create task form state

**Services:**
- `FirestoreService` — All Firestore reads/writes
- `StorageService` — Firebase Storage uploads
- `FirebaseAuthService` — Auth sign-in/sign-up

---

## 🔄 User Flows

### Onboarding Flow
- **Role Selection:** Saves preferred role to SharedPreferences.
- **Authentication:** Existing users log in; new users sign up and set up their profile (skills, experience, photo).

### Buyer Flow (Hiring Talent)
- **Discover:** Browse all open tasks in the Home feed (excluding own tasks) with search and budget filters.
- **Create:** Post new task requests with specific requirements.
- **Assign:** Chat with interested sellers and assign the task via the "Assign to Seller" button.
- **Manage & Rate:** Track assigned tasks, mark them as done, and rate the seller.

### Seller Flow (Offering Skills)
- **Find Work:** Browse open tasks from other users.
- **Bid/Message:** Use the "Message to Bid" button to contact buyers and offer services.
- **Deliver & Rate:** Fulfill assigned tasks, communicate via chat, and rate the buyer upon completion.

### "Both" Mode Toggle
Users registered with the `"Both"` role see an animated toggle in the AppBar to switch between Buyer and Seller modes instantly.

---

## 🗄 Firebase Schema

### `users/{uid}`
```json
{
  "name": "string",
  "email": "string",
  "role": "Buyer | Seller | Both",
  "currentMode": "Buyer | Seller",
  "experienceLevel": "Beginner | Intermediate | Advanced",
  "skills": ["string"],
  "photoUrl": "string?",
  "bio": "string?",
  "avgRating": "number?",
  "ratingCount": "number?"
}
```

### `tasks/{taskId}`
```json
{
  "title": "string",
  "description": "string",
  "category": "string",
  "price": "string",
  "buyerId": "string (uid)",
  "sellerId": "string (uid, empty when open)",
  "status": "open | in_progress | completed",
  "createdAt": "Timestamp"
}
```

### `orders/{orderId}`
```json
{
  "title": "string",
  "price": "string",
  "buyerId": "string (uid)",
  "sellerId": "string (uid)",
  "taskId": "string",
  "status": "Pending | Completed",
  "ratedByBuyer": "boolean",
  "ratedBySeller": "boolean",
  "createdAt": "Timestamp"
}
```

### `chats/{chatId}`
```json
{
  "participants": ["uid1", "uid2"],
  "lastMessage": "string",
  "lastMessageTimestamp": "Timestamp",
  "taskId": "string?",
  "isAssigned": "boolean"
}
```

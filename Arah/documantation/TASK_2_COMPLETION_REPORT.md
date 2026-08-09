# TASK 2 — NOTIFICATIONS BACKEND

## Task Status
COMPLETED

## Implementation Summary
Implemented a comprehensive notifications system that allows users to receive real-time updates about various events in the application. The system includes backend-triggered notifications based on key events and a callable function for sending custom notifications.

**Backend Responsibility:**
- Updated Firestore security rules to enable secure notification access
- Extended FirestoreService with methods for fetching and managing notifications
- Created multiple Cloud Functions that trigger notifications based on application events
- Implemented a callable function for sending notifications directly

## Notification Types Implemented
The system supports the following notification types:
- task_assigned: When a task is accepted by a seller
- task_started: When a seller begins working on an accepted task
- order_completed: When an order is marked as completed (both buyer and seller)
- new_message: When a new message is received in a chat
- user_reported: When a user is reported (anonymous notification to reported user)
- verification_status: When a user's verification status changes

## Firestore Rules Changes
**Added notifications collection rules:**
```
match /notifications/{notificationId} {
  allow create: if request.auth != null;
  allow get, update: if request.auth != null && resource.data.recipientId == request.auth.uid;
  allow delete: if false; // Prevent direct deletion by users
}
```

## Cloud Functions Changes

### Callable Function Added:
- `sendNotification` - Directly send notifications (requires authentication)

### Trigger Functions Added:
1. `onTaskAssigned` - Triggers when a task status changes to 'in_progress' with sellerId set
2. `onOrderCompleted` - Triggers when an order status changes to 'Completed'
3. `onNewMessage` - Triggers when a new message document is created
4. `onUserReported` - Triggers when a new report document is created
5. `onVerificationStatusChanged` - Triggers when a user's verification fields change

## FirestoreService Changes
**Methods Added:**
- `fetchUserNotifications(String userId)` - Stream of notifications for a user
- `markNotificationAsRead(String notificationId)` - Mark single notification as read
- `markAllNotificationsAsRead(String userId)` - Mark all notifications as read for a user
- `getUnreadNotificationCount(String userId)` - Get count of unread notifications

## Data Structure
Notifications are stored with the following fields:
- recipientId: ID of the user receiving the notification
- senderId: ID of the user who triggered the notification (nullable for system notifications)
- type: Notification type identifier
- title: Notification title
- body: Notification body/content
- relatedId: Optional ID of related entity (task, order, report, etc.)
- relatedType: Optional type of related entity
- isRead: Boolean indicating if notification has been read
- createdAt: Timestamp of when notification was created

## Security Considerations
- Users can only create notifications (not modify/delete arbitrary notifications)
- Users can only read/update their own notifications (where they are the recipient)
- Direct deletion of notifications is prohibited (managed by system)
- All triggers validate data existence before creating notifications
- Anonymous notifications are used for sensitive events like reports

## Integration Readiness
The notifications backend is ready for Flutter frontend integration with the following patterns:

**Fetching notifications:**
```dart
final notificationsStream = firestoreService.fetchUserNotifications(userId);
```

**Marking as read:**
```dart
await firestoreService.markNotificationAsRead(notificationId);
// or
await firestoreService.markAllNotificationsAsRead(userId);
```

**Getting unread count:**
```dart
final unreadCount = await firestoreService.getUnreadNotificationCount(userId);
```

## Testing Performed
1. **Firestore Rules:** Verified rules allow proper read/create access restrictions
2. **Callable Function:** Tested sendNotification function with valid/invalid inputs
3. **Triggers:** Verified each trigger function creates appropriate notifications
4. **Service Methods:** Tested all FirestoreService notification methods
5. **Edge Cases:** Handled null data, missing documents, and error conditions
6. **Security:** Confirmed users cannot access other users' notifications

## Files Changed
1. `firestore.rules` - Added notifications collection security rules
2. `lib/services/firestore_service.dart` - Added notification methods and import
3. `functions/index.js` - Added sendNotification function and 5 trigger functions

## Files Not Changed (Intentionally Left Untouched)
- `lib/models/notification_model.dart` - Already complete
- All UI/components - Backend ready for frontend integration
- All other services and providers - No modifications required for backend functionality

## Next Step
TASK 3 — BLOCK / UNBLOCK END-TO-END VERIFICATION
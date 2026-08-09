# Sprint 3 Frontend Integration Instructions

This document is the frontend handoff guide for the backend-dependent Sprint 3 features in ARAH. It summarizes the Firebase/Cloud Functions contracts that the UI should rely on.

## 1. Smart Matching

### Backend contract
- Cloud Function: `smartMatchTasks`
- Triggered through a callable Cloud Function from the frontend.
- Authentication is required.

### Request payload
- The caller is inferred from the authenticated user.
- Optional fields:
  - `limit`: number of matches to return
  - `lastTaskId`: pagination cursor

### Expected response
```json
{
  "matches": [
    {
      "taskId": "task_doc_id",
      "score": 0.8123,
      "task": {
        "id": "task_doc_id",
        "title": "...",
        "description": "..."
      },
      "matchBreakdown": {
        "skillCompatibility": 0.75,
        "experienceCompatibility": 0.9,
        "categoryCompatibility": 1.0,
        "beginnerPriority": 0.5
      }
    }
  ],
  "lastTaskId": "...",
  "hasMore": false
}
```

### Frontend expectations
- The UI should expect ranked results and display them in the home feed or recommendation section.
- Each match includes a `score` and a `matchBreakdown` for optional display.
- The frontend should convert each `task` object into a `TaskModel`.

### Required Firestore data
- User profile should include:
  - `skills`
  - `experienceLevel`
  - `currentMode`
- Task documents should include:
  - `status: "open"`
  - `buyerId`
  - `tags`
  - `category`
  - `isBeginnerFriendly`

### Integration note
- Ensure the backend function is deployed and accessible for authenticated users.

---

## 2. Notifications

### Backend contract
- Firestore collection: `notifications`
- Callable function: `sendNotification`
- Trigger-based notifications are also created automatically for important events.

### Required notification document fields
Each notification should include:
- `recipientId`
- `senderId`
- `type`
- `title`
- `body`
- `relatedId` (optional)
- `relatedType` (optional)
- `isRead`
- `createdAt`

### Common notification types
- `task_assigned`
- `task_started`
- `order_update`
- `user_blocked`
- `user_unblocked`
- `system`

### Frontend expectations
- The UI should subscribe to notifications for the current user.
- The notification list should display:
  - title
  - body
  - timestamp
  - read/unread state
- The UI should support marking all notifications as read.

### Integration note
- Firestore rules must allow users to read and update only their own notifications.

---

## 3. Payment, Orders, and Escrow

### Backend contract
- Firestore collection: `orders`
- The order document is created when a seller accepts/takes a task.

### Required order fields
- `title`
- `price`
- `clientName`
- `clientId`
- `buyerId`
- `buyerName`
- `sellerId`
- `sellerName`
- `taskId`
- `chatId`
- `status`
- `ratedByBuyer`
- `ratedBySeller`
- `commissionPercentage`
- `commissionAmount`
- `payoutAmount`
- `escrowStatus`
- `paymentStatus`
- `paymentReference` (optional)
- `paidAt` (optional)
- `escrowReleasedAt` (optional)
- `refundReason` (optional)
- `createdAt`

### Expected statuses
- Order status examples:
  - `Pending`
  - `in_progress`
  - `Completed`
  - `Rejected`
  - `Refunded`
- Escrow/payment states:
  - `pending`
  - `held`
  - `released`
  - `refunded`
- Payment status:
  - `pending`
  - `paid`
  - `failed`
  - `refunded`

### Commission logic
- Default commission is `15%`.
- Formula:
  - `commissionAmount = price * 15 / 100`
  - `payoutAmount = price - commissionAmount`

### Frontend expectations
- The UI should display order progress, escrow status, payment status, commission, and payout amounts.
- The frontend should update the order state based on backend changes in Firestore.

### Integration note
- The backend should maintain consistent order state transitions for payment completion and escrow release.

---

## 4. Chat File Sharing

### Backend contract
- Firebase Storage is used for attachments.
- The storage path for chat attachments should be:
  - `chats/{chatId}/{timestamp}_{filename}`

### Frontend expectations
- The UI should upload files before sending a chat message.
- The returned download URL should be saved with the message content.
- Attachments should be uploaded only for authenticated users.

### Related storage paths
- Task attachments:
  - `task_attachments/{taskId}/{filename}`
- Profile pictures:
  - `profile_pics/{uid}.jpg`

### Integration note
- Firebase Storage rules must allow authenticated users to upload and read files for the relevant chat/task scope.

---

## 5. Required backend readiness checklist

Before the frontend can complete Sprint 3 integration, confirm the following:

1. Cloud Functions are deployed successfully.
2. Firestore rules allow access to `tasks`, `orders`, `notifications`, and `users` as expected.
3. Firebase Storage rules are configured for chat and task attachments.
4. Required Firestore indexes are created where needed.
5. The backend is sending the correct field names and statuses expected by the UI.

## 6. Frontend implementation notes

The current app already expects the following integration points:
- Smart matching through the home provider and Firestore service layer.
- Notifications through Firestore streams and notification models.
- Orders and payments through the order provider and order model.
- File uploads through the storage service.

If any field name, status value, or response format changes, the UI should be updated accordingly to avoid broken rendering or failed integrations.

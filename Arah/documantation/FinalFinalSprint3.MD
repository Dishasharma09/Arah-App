# Final Final Sprint 3 Documentation

## Overview
This document summarizes the completed Sprint 3 features for ARAH, including the smart matching engine, notification backend, block/unblock enforcement, QA/test bot account management, enhanced user data handling, and escrow/commission flow.

## 1. Smart Matching Workflow

### What was implemented
- A callable Cloud Function named smartMatchTasks was added in the backend to rank open tasks for a user.
- A provider method named fetchSmartMatchedTasks was added in the home provider layer to call the function and transform the response into task objects.
- The matching algorithm uses a weighted scoring model:
  - Skills: 40%
  - Experience compatibility: 30%
  - Category compatibility: 20%
  - Beginner priority: 10%

### Backend logic
1. The client calls the smartMatchTasks callable function with the current user ID, limit, and optional lastTaskId for pagination.
2. The Cloud Function loads the caller user profile from Firestore.
3. It fetches open tasks that are not posted by the current user.
4. Each task is scored using:
   - skill overlap between the caller skills and the task tags/category
   - experience compatibility between the caller experience level and the task difficulty
   - category compatibility
   - a beginner-priority bonus for less experienced users
5. Results are sorted from highest score to lowest and returned with pagination metadata.

### Frontend flow
- The provider receives the ranked result and converts each match into a TaskModel.
- The response contains:
  - matches
  - lastTaskId
  - hasMore
  - matchBreakdowns

### Result
This gives the app a recommendation-style task discovery experience that ranks the most relevant tasks for each user.

---

## 2. Notification Backend Workflow

### What was implemented
- A NotificationModel was created to represent notification records.
- The Firestore service exposes methods to:
  - stream notifications for a user
  - mark a notification as read
  - mark all notifications as read
  - get the unread count

### Backend logic
- Notifications are stored in the notifications collection in Firestore.
- Each notification is tied to a recipientId and may include senderId, type, title, body, and related resource metadata.
- Trigger-based Cloud Functions create notifications automatically for important events such as:
  - task assignment
  - order completion
  - new messages
  - reports
  - verification status changes
  - block/unblock actions

### Frontend flow
- The app can subscribe to notifications for the signed-in user in real time.
- Unread state can be updated locally or server-side through the provided methods.

### Result
Users receive contextual updates across the platform, and notification state is trackable and queryable.

---

## 3. Block / Unblock End-to-End Verification

### What was implemented
- Block and unblock operations are supported through Firestore service methods.
- Secure versions call callable Cloud Functions that enforce admin/moderator access.

### Backend logic
1. The caller must be authenticated.
2. The caller must be an admin or moderator.
3. The target user must exist.
4. The function updates the user record to block or unblock the account.
5. A notification is generated to inform the affected user.

### Security behavior
- Admin/moderator-only execution is enforced.
- Blocking moderators or admins is prevented to reduce abuse risk.
- Notifications are sent for transparency, but the operation continues even if notification creation fails.

### Result
The platform now supports a controlled moderation workflow for account restrictions.

---

## 4. ARAH QA / Test Bot Account

### What was implemented
- A callable Cloud Function named createOrResetTestBot was added.
- The Firestore service exposes a matching method to invoke it.

### Backend logic
1. Only an authenticated admin can invoke the function.
2. The function checks whether the fixed test bot user already exists.
3. If the account exists, it is reset to a known test state.
4. If it does not exist, it is created with default QA-friendly properties.

### Test bot characteristics
- Fixed UID: test-bot-account
- Email: testbot@arah.app
- Username: testbot
- Role: Both
- Current mode: Buyer
- Verified status: true
- Skills: testing, qa, automation

### Result
This supports automated testing and QA workflows without needing the test account to be manually recreated every time.

---

## 5. User Data and Security Enhancements

### What was implemented
- The user model was extended with:
  - dateOfBirth
  - country
  - createdAt
  - lastSeen

### Why it matters
These fields support:
- profile completeness
- age-related logic and compliance readiness
- account lifecycle tracking
- activity monitoring

### Backend and storage behavior
- The model converts these values to and from Firestore-compatible timestamps and strings.
- The fields are included in the data mapping layer so they can be saved and read consistently.

### Result
The user profile model is now more complete and suitable for compliance, localization, and activity tracking.

---

## 6. Escrow and Commission Workflow

### What was implemented
- The order model now tracks commission and escrow state.
- The order provider supports order placement, completion, escrow release, and refund flows.

### Core fields
- commissionPercentage
- commissionAmount
- payoutAmount
- escrowStatus
- paymentStatus
- paymentReference
- paidAt
- escrowReleasedAt
- refundReason

### Business logic
1. When a seller accepts a task, the order is created.
2. The platform commission is calculated as 15% of the task price.
3. The seller payout is calculated as:
   - payoutAmount = taskPrice - commissionAmount
4. Initial escrow status is set to held.
5. When the work is completed, the order is marked as completed and payment status moves to paid.
6. The escrow can later be released to the seller.
7. If needed, the order can be refunded, which updates the payment and escrow statuses accordingly.

### Result
The app now has a stronger transaction flow that protects both buyers and sellers through escrow and transparent commissions.

---

## Verification Notes

### Verified implementation status
The following features are present in the relevant source files:
- smart matching provider and callable service integration
- notification service methods and notification model
- block/unblock callable service methods
- QA/test bot callable service
- expanded user profile fields
- escrow/commission order fields and provider methods

### Verification evidence
- Flutter analyzer completed successfully with no reported issues.
- The implementation exists in the following files:
  - [lib/models/user_model.dart](lib/models/user_model.dart)
  - [lib/models/notification_model.dart](lib/models/notification_model.dart)
  - [lib/models/order_model.dart](lib/models/order_model.dart)
  - [lib/provider/home_provider.dart](lib/provider/home_provider.dart)
  - [lib/provider/order_provider.dart](lib/provider/order_provider.dart)
  - [lib/services/firestore_service.dart](lib/services/firestore_service.dart)
  - [functions/index.js](functions/index.js)

## Conclusion
Sprint 3 is implemented end to end for the major requested capabilities. The app now includes smart task matching, notification delivery, moderation controls, QA support, richer user profiles, and escrow-based order handling.

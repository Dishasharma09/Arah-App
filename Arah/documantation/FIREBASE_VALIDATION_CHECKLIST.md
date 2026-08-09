# Firebase Validation & Integration QA Checklist
## Sprint 3 Features Validation

This document provides a comprehensive checklist for validating all Sprint 3 backend features against a live Firebase environment.

## Prerequisites
Before running validation:
1. Firebase CLI installed and logged in (`firebase login`)
2. Firebase project initialized (`firebase init`)
3. Emulator suite available for testing (`firebase emulators:start`)
4. Or access to live Firebase project (use with caution)

## Validation Sections

### 1. Environment Setup Validation
- [ ] Firebase CLI installed: `firebase --version`
- [ ] Firebase project initialized: `firebase list`
- [ ] Functions deployed or emulators running
- [ ] Firestore rules deployed
- [ ] Emulators started: `firebase emulators:start --only functions,firestore`

### 2. Smart Matching Validation (TASK 1)
#### Cloud Function: smartMatchTasks
- [ ] Function deploys without errors
- [ ] Requires authentication (returns UNAUTHENTICATED when no auth)
- [ ] Returns properly formatted response with matches array
- [ ] Handles pagination correctly (lastTaskId parameter)
- [ ] Respects limit parameter
- [ ] Returns empty array when no matches found
- [ ] Scores matches based on weighted algorithm:
  - Skills match: 40%
  - Experience level compatibility: 30%
  - Category matching: 20%
  - Beginner priority bonus: 10%
- [ ] Excludes user's own tasks
- [ ] Only returns open tasks
- [ ] Performance: Returns within reasonable time (<5s for small datasets)

#### Firestore Service Method: smartMatchTasks()
- [ ] Method exists in FirestoreService
- [ ] Properly calls Cloud Function
- [ ] Handles FirebaseExceptions correctly
- [ ] Returns Map<String, dynamic> with expected structure

#### Firestore Indexes
- [ ] Required indexes created for smart matching queries
- [ ] No unindexed query warnings in logs

#### HomeProvider
- [ ] fetchSmartMatchedTasks method implemented
- [ ] Properly processes function response
- [ ] Handles loading and error states
- [ ] Updates UI with matched tasks

### 3. Notifications Backend Validation (TASK 2)
#### Firestore Rules: notifications collection
- [ ] Users can create notifications
- [ ] Users can only read/update their own notifications (recipientId matches)
- [ ] Users cannot delete notifications
- [ ] Security rules properly enforced

#### Cloud Function: sendNotification
- [ ] Function deploys without errors
- [ ] Requires authentication
- [ ] Creates notification document with correct fields
- [ ] Sets isRead: false by default
- [ ] Sets createdAt timestamp
- [ ] Handles missing data gracefully

#### Event Trigger Functions
All 5 trigger functions deploy correctly:
- [ ] onTaskAssigned
- [ ] onOrderCompleted
- [ ] onNewMessage
- [ ] onUserReported
- [ ] onVerificationStatusChanged

#### FirestoreService Notification Methods
- [ ] fetchUserNotifications(stream) returns correct stream
- [ ] markNotificationAsRead updates isRead field
- [ ] markAllNotificationsAsRead updates all user's notifications
- [ ] getUnreadNotificationCount returns correct count
- [ ] All methods handle FirebaseExceptions properly

### 4. Block/Unblock End-to-End (TASK 3)
#### Cloud Functions: blockUser & unblockUser
- [ ] Both functions deploy without errors
- [ ] Require authentication
- [ ] Validate caller is admin or moderator
- [ ] Validate target user exists
- [ ] Prevent admins/moderators from blocking each other
- [ ] Update isBlocked field correctly
- [ ] Set blockedAt/unblockedAt timestamps
- [ ] Send notification to blocked/unblocked user
- [ ] Handle errors gracefully (notification failure doesn't block operation)
- [ ] Return proper success response

#### Security Validation
- [ ] Regular users cannot call these functions (PERMISSION_DENIED)
- [ ] Admins/moderators can call functions
- [ ] Function properly validates input (missing uid returns INVALID_ARGUMENT)
- [ ] Non-existent user returns NOT_FOUND

#### FirestoreService Wrapper Methods
- [ ] blockUserSecure and unblockUserSecure methods exist
- [ ] Properly call Cloud Functions
- [ ] Handle FirebaseExceptions and rethrow as FirebaseException

### 5. QA/Test Bot Account (TASK 4)
#### Cloud Function: createOrResetTestBot
- [ ] Function deploys without errors
- [ ] Requires admin authentication
- [ ] Creates/updates test bot account with fixed UID: 'test-bot-account'
- [ ] Sets predefined properties:
  - Email: testbot@arah.app
  - Username: testbot
  - Name: ARAH Test Bot
  - Role: Admin
  - ExperienceLevel: Expert
  - Skills: ['testing', 'qa', 'automation']
  - bio: "Automated test account for ARAH platform QA"
  - isProfilePublic: true
  - dateOfBirth: 1990-01-01 (or similar fixed date)
  - country: "United States"
  - createdAt and lastSeen set to current timestamp
- [ ] Function is idempotent (can be called multiple times)
- [ ] Returns success response

#### FirestoreService Method
- [ ] createOrResetTestBot() method exists
- [ ] Properly calls Cloud Function
- [ ] Handles FirebaseExceptions correctly

### 6. User Data & Security Rules (TASK 5)
#### UserModel Enhancements
- [ ] dateOfBirth field added (DateTime?)
- [ ] country field added (String?)
- [ ] createdAt field added (DateTime?)
- [ ] lastSeen field added (DateTime?)
- [ ] All new fields properly handled in:
  - constructor
  - fromMap()
  - toMap()
  - copyWith()

#### Firestore Rules: users collection
- [ ] dateOfBirth immutability enforced:
  - Can be set once during profile creation
  - Cannot be changed after initial set
  - Validation: !request.resource.data.containsKey('dateOfBirth') || request.resource.data.get('dateOfBirth') == resource.data.get('dateOfBirth')
- [ ] country field validation:
  - Length validation: size() <= 100 characters
- [ ] lastSeen timestamp validation:
  - Is timestamp when present
- [ ] Protected fields still protected:
  - isAdmin, isModerator, isBlocked cannot be updated directly
- [ ] Allowed updates still work:
  - name, bio, experienceLevel, skills, photoUrl, githubUrl, linkedinUrl, isProfilePublic, username, lastSeen

#### UserProvider
- [ ] setupProfile() method updated:
  - Requires dateOfBirth and country parameters
  - Automatically sets createdAt and lastSeen to DateTime.now()
  - Maintains intentional breaking change for data completeness
- [ ] Existing methods still work:
  - loadUser, updateProfile, switchMode, etc.

### 7. Escrow & Commission (TASK 6)
#### OrderModel
- [ ] New fields added:
  - commissionPercentage: double (default 15.0)
  - commissionAmount: double
  - payoutAmount: double
  - escrowStatus: String ('pending', 'held', 'released', 'refunded')
  - paymentStatus: String ('pending', 'paid', 'failed', 'refunded')
  - paymentReference: String?
  - paidAt: DateTime?
  - escrowReleasedAt: DateTime?
  - refundReason: String?
- [ ] All new fields properly handled in:
  - constructor (with sensible defaults)
  - fromMap()
  - toMap()

#### FirestoreService.placeTaskOrder() Updates
- [ ] Calculates 15% commission from task price
- [ ] Sets escrowStatus to 'held' initially
- [ ] Sets paymentStatus to 'pending' initially
- [ ] Calculates payoutAmount = price - commissionAmount
- [ ] Properly handles price parsing (removes currency symbols)
- [ ] Uses batch transaction for task update + order creation

#### OrderProvider
- [ ] All methods implemented with proper error handling:
  - fetchUserOrders(buyerId, statuses)
  - fetchSellerOrders(sellerId, statuses)
  - placeTaskOrder(...) - with commission calculation
  - updateOrderStatus(orderId, status)
  - updateOrderFields(orderId, fields) - flexible updates
  - completeOrder(orderId, taskId) - marks payment as paid
  - releaseEscrow(orderId) - sets escrowStatus to 'released'
  - refundOrder(orderId, reason) - marks as refunded
- [ ] Helper getters:
  - activeOrders (Pending, in_progress, Completed)
  - completedOrders (Completed, Refunded)
- [ ] Proper loading and error states
- [ ] Notifies listeners appropriately

#### Integration Points
- [ ] Orders collection Firestore rules compatible with new fields
- [ ] Existing order-related functionality still works
- [ ] Commission calculation uses percentage (allows easy configuration changes)
- [ ] Escrow status flow: pending → held → released/refunded
- [ ] Payment status flow: pending → paid/failed/refunded

### 8. End-to-End Integration Testing
#### User Flows to Test
- [ ] New user registration → profile setup with DOB/country → appears in smart matching
- [ ] Buyer posts task → seller sees task in smart matches → seller takes order → order created with commission
- [ ] Order lifecycle: Pending → (payment simulation) → Completed → escrow released → payment processed
- [ ] Notifications triggered at each step:
  - Task assigned notification
  - Order completed notification
  - New message notification (if chat used)
  - User reported notification (if reporting used)
  - Verification status changed notification (if verification implemented)
- [ ] Block/unblock workflow:
  - Admin blocks user → user gets notification → user has limited access
  - Admin unblocks user → user gets notification → access restored
- [ ] Test bot account:
  - Admin creates/resets test bot → test bot appears with predefined properties
  - Test bot can be used for testing other features
- [ ] Escrow/commission flow verification:
  - Correct commission percentage applied
  - Correct payout calculated
  - Escrow held until released
  - Payment status tracked correctly

#### Data Consistency Checks
- [ ] No orphaned records (orders without valid task/user references)
- [ ] Timestamps set correctly (createdAt, paidAt, escrowReleasedAt)
- [ ] Commission math accurate (price * commissionPercentage / 100)
- [ ] Payout + commission = original price (within floating point precision)
- [ ] Status transitions logical (cannot skip steps)

## Validation Procedures

### Using Firebase Emulators (Recommended for Testing)
1. Start emulators: `firebase emulators:start --only functions,firestore`
2. Run tests against localhost:5001 (functions) and localhost:8080 (firestore)
3. Use Firebase test SDK or manual API calls
4. Validate all functions work as expected
5. Check Firestore rules are enforced

### Using Live Firebase Project (With Caution)
1. Point to test project, not production
2. Use test user accounts
3. Clean up test data after validation
4. Monitor usage and costs
5. Validate in short bursts

### Manual Validation Steps
For each feature:
1. Deploy functions: `firebase deploy --only functions`
2. Deploy rules: `firebase deploy --only firestore:rules`
3. Test via Flutter app or API client (Postman/curl)
4. Verify expected behavior and error cases
5. Check logs for any warnings or errors
6. Validate Firestore document structure

## Expected Outcomes
All validations should pass with:
- No function deployment errors
- No Firestore rule deployment errors
- All features working as designed
- Proper error handling and validation
- Security rules enforced correctly
- Data consistency maintained
- Performance within acceptable limits

## Troubleshooting Guide
Common issues to check:
1. Function deployment failures: Check logs for syntax errors, missing dependencies
2. Firestore rule errors: Simulator shows exactly what rule denied access
3. Missing fields: Ensure model toMap()/fromMap() match Firestore document structure
4. Timeout issues: Consider query complexity, add indexes if needed
5. Permission denied: Verify auth context and rule conditions
6. Missing indexes: Firebase suggests required indexes in error messages

## Sign-off Criteria
[ ] All Smart Matching features validated
[ ] All Notifications features validated  
[ ] All Block/Unblock features validated
[ ] QA/Test Bot Account validated
[ ] All User Data & Security Rules validated
[ ] All Escrow & Commission features validated
[ ] End-to-end integration flows tested
[ ] No critical bugs or regressions found
[ ] Performance acceptable for intended use
[ ] Security validated (no privilege escalation, data leaks)

## Validation Completed By: _______________________
## Date: _______________________
## Firebase Project ID: _______________________
## Environment: [ ] Emulators [ ] Test Project [ ] Live Project (specify: ___________)

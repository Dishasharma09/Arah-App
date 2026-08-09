# Sprint 2 Stage 3: Block / Unblock User Implementation Summary

## Overview
This document summarizes the backend implementation for Stage 3 of Sprint 2: Block/Unblock User functionality for the ARAH Flutter + Firebase application.

## Features Implemented
✅ Secure block/unblock user functionality via Cloud Functions
✅ Admin/moderator-only access control
✅ Proper Firestore security rules integration
✅ Backend validation and error handling
✅ Service methods for client integration

## Files Modified

### 1. `functions/index.js` (Cloud Functions)
**Added:**
- `blockUser` - Callable function to block a user (admin/moderator only)
- `unblockUser` - Callable function to unblock a user (admin/moderator only)

**Features:**
- Authentication verification (`request.auth` check)
- Authorization verification (caller must be admin or moderator)
- Input validation (target UID must be non-empty string)
- Prevention of self-blocking
- Target user existence verification
- Proper error handling with HTTP error codes
- Logging for audit trails

### 2. `lib/services/firestore_service.dart`
**Added:**
- `blockUserSecure(String userId)` - Wrapper for secure blockUser Cloud Function
- `unblockUserSecure(String userId)` - Wrapper for secure unblockUser Cloud Function
- Maintained existing `blockUser()` and `unblockUser()` methods for direct Firestore access (though secure versions are recommended)

### 3. `lib/provider/user_provider.dart`
**Added:**
- Import for `cloud_functions/cloud_functions.dart`
- `blockUserSecure(String userId)` method - Calls secure Cloud Function
- `unblockUserSecure(String userId)` method - Calls secure Cloud Function

## Security Considerations Implemented

### 1. **Authentication & Authorization**
- All block/unblock operations require authentication
- Only administrators and moderators can block/unblock users
- Caller verification via Firestore user document (`isAdmin` and `isModerator` fields)

### 2. **Input Validation**
- Target user ID must be a non-empty string
- Prevention of self-blocking (users cannot block themselves)
- Target user existence verification before attempting operations

### 3. **Operation Security**
- Block operation sets `isBlocked: true` and `blockedAt: Timestamp`
- Unblock operation sets `isBlocked: false`, `unblockedAt: Timestamp`, and clears `blockedAt`
- All operations use Firestore server timestamps for consistency
- Proper error propagation from Cloud Functions to client

### 4. **Integration with Existing Security Rules**
The implementation leverages existing Firestore Security Rules that automatically prevent blocked users from:
- Creating new tasks (tasks collection)
- Creating new orders (orders collection)  
- Participating in chats (chats collection)
- Updating/deleting their existing items in the above collections

*Note: Reading existing content is still possible in some cases to preserve conversation history and audit trails, but initiating new interactions is blocked.*

## Firestore Structure Utilized
Uses existing `users/{userId}` document structure:
- `isBlocked`: Boolean indicating if user is blocked
- `blockedAt`: Timestamp when user was blocked (optional)
- `unblockedAt`: Timestamp when user was unblocked (optional)

## Backend Logic Flow

### Block User Process:
1. User initiates block request through UI
2. Client calls `UserProvider.blockUserSecure(targetUserId)`
3. Calls Cloud Function `blockUser` via Firebase Functions
4. Function verifies:
   - Caller is authenticated
   - Caller is admin or moderator (checks their user document)
   - Target user ID is valid
   - Target user exists
   - Prevents self-blocking
5. Function updates target user's document:
   - Sets `isBlocked: true`
   - Sets `blockedAt: FieldValue.serverTimestamp()`
6. Success result returned to client

### Unblock User Process:
1. Similar to block process but uses `unblockUser` Cloud Function
2. Function updates target user's document:
   - Sets `isBlocked: false`
   - Sets `unblockedAt: FieldValue.serverTimestamp()`
   - Clears `blockedAt` field with `FieldValue.delete()`

## API Contract

### blockUser Cloud Function
**Request:**
```javascript
{
  uid: "targetUserIdString"  // Required: ID of user to block
}
```

**Response:**
```javascript
{
  success: true,
  uid: "targetUserIdString"
}
```

**Errors:**
- `unauthenticated`: User must be authenticated
- `invalid-argument`: Target user ID must be a non-empty string
- `failed-precondition`: Users cannot block themselves
- `not-found`: Caller or target user not found
- `permission-denied`: Only administrators and moderators can block users
- `internal`: Unable to block user

### unblockUser Cloud Function
**Request:**
```javascript
{
  uid: "targetUserIdString"  // Required: ID of user to unblock
}
```

**Response:**
```javascript
{
  success: true,
  uid: "targetUserIdString"
}
```

**Errors:**
- Same as blockUser function with appropriate messages

## Dependencies
- `cloud_functions`: Already present from Stage 1
- No new dependencies required

## Testing Checklist

### Manual Test Cases

#### ✅ Secure Block/Unblock Operations
1. Authenticated admin can block any user
2. Authenticated moderator can block any user
3. Regular user cannot block anyone (permission denied)
4. Unauthenticated user cannot block/unblock (authentication required)
5. Blocking non-existent user returns error
6. Self-blocking is prevented
7. Blocked user data is correctly updated in Firestore
8. Unblocking reverses the block operation correctly

#### ✅ Integration with Security Rules
1. Blocked user cannot create new tasks
2. Blocked user cannot create new orders
3. Blocked user cannot create new chat messages
4. Blocked user cannot update/delete their existing items in above collections
5. Non-blocked users retain normal functionality
6. Admin/moderator privileges override restrictions when appropriate

#### ✅ Error Handling
1. All error conditions return appropriate FirebaseException types
2. Error messages are user-friendly and descriptive
3. Stack traces are logged for debugging but not exposed to users
4. Network failures are properly handled and reported

#### ✅ Edge Cases
1. Blocking already-blocked user (should succeed but be idempotent)
2. Unblocking already-unblocked user (should succeed but be idempotent)
3. Attempting to block/unblock user that was recently deleted
4. High-frequency block/unblock requests (rate limiting consideration)

## Status
**READY FOR REVIEW AND DEPLOYMENT**

The backend implementation for Stage 3 is complete and ready for:
1. Deployment of Cloud Functions: `firebase deploy --only functions`
2. Integration testing with frontend (no frontend changes required for core functionality)
3. Proceed to next stage upon approval
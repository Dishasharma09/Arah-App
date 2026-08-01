# Stage 3 Summary: Block / Unblock User Implementation

## Overview
This document summarizes the backend implementation for Stage 3 of Sprint 2: Block/Unblock User functionality for the ARAH Flutter + Firebase application.

## Features Implemented
✅ Block user functionality  
✅ Unblock user functionality  
✅ Prevent blocked users from interacting with the app  
✅ Firestore updates for user blocking status  
✅ Backend validation for block/unblock operations  
✅ Enhanced Security Rules with role-based access control  
✅ User model extension with isBlocked, isAdmin, isModerator fields  

## Files Modified

### 1. `lib/models/user_model.dart`
**Added:**
- `isBlocked` field - Tracks whether a user is blocked (default: false)
- `isAdmin` field - Identifies administrators with elevated privileges (default: false)
- `isModerator` field - Identifies moderators with content management privileges (default: false)
- Updated constructor, factory methods, `toMap()`, and `copyWith()` to include new fields

### 2. `lib/services/firestore_service.dart`
**Added:**
- `blockUser(String userId)` method - Blocks a user by setting `isBlocked` to true
  - Validates target user exists before blocking
  - Sets `blockedAt: FieldValue.serverTimestamp()` for audit tracking
  - Restricted to admins/moderators via security rules
  
- `unblockUser(String userId)` method - Unblocks a user by setting `isBlocked` to false
  - Validates target user exists before unblocking
  - Sets `unblockedAt: FieldValue.serverTimestamp()` for audit tracking
  - Clears `blockedAt` field using `FieldValue.delete()`
  - Restricted to admins/moderators via security rules

### 3. `firestore.rules` (Updated)
**Enhanced Security Rules:**

**Users Collection:**
- Prevents blocked users from reading/updating their own profiles (except via admin/mod pathways)
- Allows admins/mods to access blocked user accounts for management purposes
- Prevents blocked users from creating new profiles
- Profile updates allowed only if user is not blocked OR requester is admin/mod
- Profile deletion disabled to prevent accidental account removal

**Reports Collection:**
- Maintains existing functionality
- Adds explicit admin/moderator access for reading/updating reports

**Tasks Collection:**
- Blocks blocked users from creating tasks
- Prevents blocked users from updating/deleting tasks
- Allows both buyers and sellers to update tasks (sellers when taking orders, buyers for their own tasks)
- Task deletion restricted to buyers only

**Orders Collection:**
- Blocks blocked users from creating, reading, updating, or deleting orders
- Order access restricted to buyer or seller of the order (if not blocked)
- Order updates/deletes require user to be buyer or seller and not blocked

**Chats Collection:**
- Prevents blocked users from participating in chats
- Blocks message sending/receiving for blocked users
- Chat access restricted to participants only (if not blocked)

### 4. `firebase.json` (Unchanged)
No changes needed as Firestore configuration was already set up in Stage 2.

## Firestore User Structure
```
/users/{userId}
  ├── name: string
  ├── email: string
  ├── role: string ("Buyer", "Seller", "Both")
  ├── currentMode: string ("Buyer" or "Seller")
  ├── bio: string
  ├── experienceLevel: string
  ├── skills: array
  ├── photoUrl: string? (optional)
  ├── githubUrl: string
  ├── linkedinUrl: string
  ├── isProfilePublic: boolean
  ├── isBlocked: boolean (NEW: false = active, true = blocked)
  ├── isAdmin: boolean (NEW: admin privileges)
  ├── isModerator: boolean (NEW: moderator privileges)
  ├── avgRating: number (0-5)
  ├── ratingCount: integer
  ├── blockedAt: timestamp? (optional: when user was blocked)
  └── unblockedAt: timestamp? (optional: when user was unblocked)
```

## Security Considerations Implemented

### 1. User Model Enhancement
- Added `isBlocked` flag to track user status
- Added `isAdmin` and `isModerator` for role-based access control
- Added timestamp fields for audit tracking (`blockedAt`, `unblockedAt`)
- Maintained backward compatibility with existing user data

### 2. Authentication & Authorization
- **Blocking/Unblocking Operations**: Restricted to users with `isAdmin` or `isModerator` = true via security rules
- **Blocked User Restrictions**: 
  - Cannot read/update own profile (except via admin/mod pathways)
  - Cannot create new content (tasks, orders)
  - Cannot participate in chats
  - Cannot access most Firestore resources
- **Admin/Moderator Privileges**:
  - Can view and manage blocked user accounts
  - Can access all reports for moderation
  - Can perform block/unblock operations
  - Can bypass certain restrictions for management purposes

### 3. Data Integrity
- Server-side timestamps for blocking/unblocking events
- Validation checks in service methods (user existence)
- Atomic Firestore operations for consistency
- Proper cleanup of `blockedAt` timestamp when unblocking

### 4. Abuse Prevention
- Role-based access prevents unauthorized blocking/unblocking
- Comprehensive blocking prevents malicious users from continuing harmful behavior
- Audit trails track when actions occurred and potentially who performed them
- Defense-in-depth: both application logic and security rules enforce restrictions

## Backend Logic Flow

### Blocking a User:
1. **Request Validation**: Verify target user exists
2. **Permission Check** (via security rules): Confirm requester is admin/moderator
3. **Data Update**: Set `isBlocked: true`, add `blockedAt` timestamp
4. **Effect**: User immediately restricted from most app functions

### Unblocking a User:
1. **Request Validation**: Verify target user exists
2. **Permission Check** (via security rules): Confirm requester is admin/moderator
3. **Data Update**: Set `isBlocked: false`, add `unblockedAt` timestamp, remove `blockedAt`
4. **Effect**: User regains normal access to app features

### Runtime Enforcement:
- All Firestore operations check `isBlocked` status via security rules
- Blocked users receive permission denied errors for restricted operations
- Admin/moderator operations bypass standard user restrictions

## Firestore Security Rules Enhancements

### Core Protection Mechanism:
```javascript
// Example pattern used throughout rules
!(getAfter(/databases/$(database)/documents/users/$(request.auth.uid)).data.isBlocked == true)
```

### Admin/Moderator Bypass:
```javascript
getAfter(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true ||
getAfter(/databases/$(database)/documents/users/$(request.auth.uid)).data.isModerator == true
```

## Dependencies
- `cloud_firestore`: Already present in pubspec.yaml
- No new dependencies required for this stage

## Testing Checklist

### Manual Test Cases

#### ✅ Block User Operation
1. Admin calls `blockUser()` on valid user → Success, user.isBlocked = true
2. Non-admin attempts `blockUser()` → Permission denied
3. Attempt to block non-existent user → "User not found" error
4. Blocked user attempts to sign in → Can authenticate but gets restricted access
5. Blocked user tries to update profile → Permission denied
6. Blocked user tries to create task/order → Permission denied
7. Admin can still access blocked user's profile → Success

#### ✅ Unblock User Operation
1. Admin calls `unblockUser()` on blocked user → Success, user.isBlocked = false
2. Non-admin attempts `unblockUser()` → Permission denied
3. Attempt to unblock non-blocked user → Success (no-op, but updates timestamps)
4. Previously blocked user regains full access after unblocking

#### ✅ Security & Restrictions
1. Blocked user cannot:
   - Read/update own profile (except through admin channels)
   - Create new tasks, orders, or reports
   - Send/receive chat messages
   - Access most protected resources
   
2. Admin/Moderator can:
   - Block/unblock any user
   - View all reports regardless of involvement
   - Access blocked user profiles for management
   - Perform all standard user operations

#### ✅ Edge Cases
1. Blocking already blocked user → Updates `blockedAt` timestamp
2. Unblocking already unblocked user → Updates `unblockedAt` timestamp
3. Rapid block/unblock cycles → Maintains correct state with timestamps
4. Network interruption during operation → Atomic updates ensure consistency
5. Concurrent block/unblock requests → Last write wins with timestamp ordering

#### ✅ Integration
1. Existing functionality unaffected for non-blocked users
2. Reports system continues to work normally
3. Authentication flow unchanged
4. Data persistence maintained across app restarts

## API Contract

### Block User
**Method:** `FirestoreService.blockUser(String userId)`  
**Parameters:**
- `userId` (String, required): ID of user to block  
**Returns:** Future<void>  
**Throws:** 
- Exception with "User not found: $userId" if user doesn't exist
- Permission denied via security rules if caller lacks admin/moderator role

### Unblock User
**Method:** `FirestoreService.unblockUser(String userId)`  
**Parameters:**
- `userId` (String, required): ID of user to unblock  
**Returns:** Future<void>  
**Throws:** 
- Exception with "User not found: $userId" if user doesn't exist
- Permission denied via security rules if caller lacks admin/moderator role

## Status
**Stage 3 Block/Unblock User Implementation: COMPLETE** ✅

The backend implementation is complete, secure, and ready for deployment. All requirements have been met with defense-in-depth principles, ensuring both application logic and security rules enforce the blocking restrictions.

**Next Step:** Upon confirmation of completion, proceed to Stage 4 — User Management (username validation, uniqueness, profile storage, public profile setting, verification status).
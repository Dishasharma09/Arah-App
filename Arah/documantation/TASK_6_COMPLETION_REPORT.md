# TASK 6 — ESCROW & COMMISSION

## Task Status
COMPLETED

## Implementation Summary
Implemented escrow and commission system for the ARAH platform. Added financial tracking fields to orders, including commission percentage, commission amount, payout amount, escrow status, payment status, and related timestamps. Updated order placement logic to calculate commission and set initial escrow status.

## Backend Responsibility:
- Added commission and escrow fields to OrderModel
- Updated FirestoreService.placeTaskOrder to calculate commission (15%) and set initial escrow status as 'held'
- Created OrderProvider with methods to manage orders, including:
  * fetchUserOrders and fetchSellerOrders
  * placeTaskOrder (with commission calculation)
  * updateOrderStatus and updateOrderFields
  * completeOrder (marks payment as paid)
  * releaseEscrow (releases funds to seller)
  * refundOrder (refunds order with reason)
- Updated FirestoreService with updateOrderFields method for flexible order updates

## OrderModel Changes
**Fields Added:**
- `commissionPercentage`: double - Platform commission percentage (default 15.0)
- `commissionAmount`: double - Actual commission amount in currency
- `payoutAmount`: double - Amount seller receives after commission
- `escrowStatus`: String - Status of escrow funds ('pending', 'held', 'released', 'refunded')
- `paymentStatus`: String - Payment processing status ('pending', 'paid', 'failed', 'refunded')
- `paymentReference`: String? - Transaction ID from payment processor
- `paidAt`: DateTime? - When payment was received
- `escrowReleasedAt`: DateTime? - When escrow was released to seller
- `refundReason`: String? - If refunded, reason for refund

**Updated Methods:**
- `fromMap()`: Handles deserialization of new fields from Firestore
- `toMap()`: Serializes new fields for storage in Firestore

## FirestoreService Changes
**Updated placeTaskOrder method:**
- Calculates commission based on 15% platform fee
- Sets escrowStatus to 'held' (funds held in escrow initially)
- Sets paymentStatus to 'pending' (payment pending from buyer)
- Computes payoutAmount as price minus commission

**Added method:**
- `updateOrderFields(String orderId, Map<String, dynamic> fields)` - Updates specific fields in an order document

## OrderProvider Changes
**Implemented methods:**
- `fetchUserOrders(String userId, List<String> statuses)` - Fetches orders where user is buyer
- `fetchSellerOrders(String userId, List<String> statuses)` - Fetches orders where user is seller
- `placeTaskOrder({...})` - Creates order with commission calculation
- `updateOrderStatus(String orderId, String status)` - Updates order status
- `updateOrderFields(String orderId, Map<String, dynamic> fields)` - Updates order fields
- `completeOrder(String orderId, String taskId)` - Marks order as completed and payment as paid
- `releaseEscrow(String orderId)` - Releases escrow to seller
- `refundOrder(String orderId, String reason)` - Refunds order
- Helper getters for activeOrders and completedOrders

## Security Considerations
- The orders collection Firestore rules remain as `allow read, write: if request.auth != null;` (existing pattern)
- No changes made to authentication or authorization logic
- Financial calculations performed client-side (in Flutter) before writing to Firestore
- Commission percentage hardcoded at 15% for consistency (can be made configurable in future)

## Files Modified
1. `lib/models/order_model.dart` - New file with OrderModel class
2. `lib/provider/order_provider.dart` - Rewritten to use OrderModel and implement order management
3. `lib/services/firestore_service.dart` - Updated placeTaskOrder method and added updateOrderFields method

## Files Not Changed (Intentionally Left Untouched)
- `firestore.rules` - Existing orders rules are permissive but compatible with new fields
- `lib/provider/user_provider.dart` - No changes needed for escrow/commission
- `lib/provider/home_provider.dart` - No changes needed
- UI Components - Will be updated separately to display commission/escrow information

## Next Step
TASK 7 — LIVE FIREBASE VALIDATION & INTEGRATION QA
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/bottom_nav_bar.dart';
import '../../provider/order_provider.dart';
import '../../provider/user_provider.dart';
import '../chat/chat_screen.dart';
import '../../models/order_model.dart';

class MyOrdersScreen extends StatefulWidget {
  final bool isSeller;
  const MyOrdersScreen({super.key, this.isSeller = false});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool isActive = true;

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final displayOrders =
        isActive ? orderProvider.activeOrders : orderProvider.completedOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: Text(
          widget.isSeller ? 'My Work' : 'My Orders',
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      bottomNavigationBar:
          ArahBottomNavBar(currentIndex: 1, isSeller: widget.isSeller),
      body: SafeArea(
        child: Column(
          children: [
            // Tab Toggle
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTab('Pending', true),
                    _buildTab('Completed', false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: orderProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.arahPurple))
                  : displayOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: displayOrders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(
                                context, displayOrders[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, bool isActiveTab) {
    final isSelected = isActive == isActiveTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isActive = isActiveTab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.navyBlue : Colors.blueGrey.shade500,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    final currentUid = context.read<UserProvider>().uid;
    
    final computedClientName = widget.isSeller
        ? (order.buyerName.isNotEmpty ? order.buyerName : order.clientName)
        : (order.sellerName.isNotEmpty ? order.sellerName : order.clientName);
    final computedClientInitial =
        computedClientName.isNotEmpty ? computedClientName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        order.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navyBlue,
                          fontSize: 16,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      order.price,
                      style: const TextStyle(
                        color: AppTheme.arahPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.arahPurple.withOpacity(0.1),
                      child: Text(
                        computedClientInitial,
                        style: const TextStyle(
                          color: AppTheme.arahPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        computedClientName,
                        style: TextStyle(
                          color: Colors.blueGrey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _buildStatusBadge(order.status),
                  ],
                ),
              ],
            ),
          ),
          // Action Buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: const Color(0xFFE2E8F0)),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _buildActionButtons(context, order, currentUid),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, OrderModel order, String currentUid) {
    final isCompleted = order.status == 'Completed';

    if (isCompleted) {
      // Completed order: show Chat + optional Rate button
      final hasRated = widget.isSeller ? order.ratedBySeller : order.ratedByBuyer;
      return Row(
        children: [
          Expanded(
            child: _actionButton(
              label: 'Chat',
              icon: Icons.chat_bubble_outline,
              color: AppTheme.navyBlue,
              onPressed: () => _openChat(context, order, currentUid),
              outlined: true,
            ),
          ),
          if (!hasRated) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _actionButton(
                label: 'Rate',
                icon: Icons.star_outline,
                color: const Color(0xFFF59E0B),
                onPressed: () =>
                    _showRatingDialog(context, order, currentUid),
              ),
            ),
          ],
        ],
      );
    }

    final isPendingApproval = order.status == 'PendingApproval';

    // Pending or PendingApproval orders
    if (widget.isSeller) {
      if (isPendingApproval) {
        return Row(
          children: [
            Expanded(
              child: _actionButton(
                label: 'Reject',
                icon: Icons.close,
                color: const Color(0xFFEF4444),
                onPressed: () => context.read<OrderProvider>().rejectOrder(order.id),
                outlined: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionButton(
                label: 'Accept',
                icon: Icons.check,
                color: const Color(0xFF10B981),
                onPressed: () => context.read<OrderProvider>().acceptOrder(order.id),
              ),
            ),
          ],
        );
      }

      // Seller: only Chat (no assignment controls) for active orders
      return _actionButton(
        label: 'Open Chat',
        icon: Icons.chat_bubble_outline,
        color: AppTheme.arahPurple,
        onPressed: () => _openChat(context, order, currentUid),
      );
    } else {
      if (isPendingApproval) {
        return SizedBox(
          width: double.infinity,
          child: _actionButton(
            label: 'Awaiting Approval...',
            icon: Icons.hourglass_empty,
            color: Colors.blueGrey.shade400,
            onPressed: () {}, // disabled state effectively
          ),
        );
      }

      // Buyer: Chat + Mark as Completed + Remove/Reassign
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: 'Chat',
                  icon: Icons.chat_bubble_outline,
                  color: AppTheme.navyBlue,
                  onPressed: () => _openChat(context, order, currentUid),
                  outlined: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  label: 'Completed Order',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF10B981),
                  onPressed: () =>
                      _markAsCompleted(context, order),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _actionButton(
              label: 'Remove & Reassign',
              icon: Icons.refresh,
              color: const Color(0xFFEF4444),
              onPressed: () => _showReassignDialog(context, order),
              outlined: true,
            ),
          ),
        ],
      );
    }
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    return outlined
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color, width: 1),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    switch (status) {
      case 'Completed':
        badgeColor = const Color(0xFF10B981);
        break;
      case 'Pending':
        badgeColor = AppTheme.arahPurple;
        break;
      case 'PendingApproval':
        badgeColor = const Color(0xFFF59E0B);
        break;
      case 'Rejected':
        badgeColor = const Color(0xFFEF4444);
        break;
      default:
        badgeColor = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _openChat(
      BuildContext context, OrderModel order, String currentUid) {
    final otherUserId =
        widget.isSeller ? order.buyerId : order.sellerId;
    final chatId = order.chatId.isNotEmpty
        ? order.chatId
        : _buildChatId(currentUid, otherUserId);

    final computedClientName = widget.isSeller
        ? (order.buyerName.isNotEmpty ? order.buyerName : order.clientName)
        : (order.sellerName.isNotEmpty ? order.sellerName : order.clientName);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: otherUserId,
          otherUserName: computedClientName,
          taskId: order.taskId,
          taskTitle: order.title,
          taskPrice: order.price,
          isBuyer: !widget.isSeller,
        ),
      ),
    );
  }

  String _buildChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _markAsCompleted(
      BuildContext context, OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Completed?',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
        content: const Text(
            'Confirm that the work has been delivered to your satisfaction. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await context.read<OrderProvider>().completeOrder(order.id, order.taskId);
      if (mounted) {
        _showRatingDialog(context, order, context.read<UserProvider>().uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete order: $e')),
        );
      }
    }
  }

  Future<void> _showReassignDialog(
      BuildContext context, OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove & Reassign?',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.navyBlue)),
        content: const Text(
            'This will remove the current seller assignment and put the task back on the open marketplace. You can then assign a new seller.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove Seller'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await context
          .read<OrderProvider>()
          .reassignOrder(order.id, order.taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task is back on the marketplace!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reassign: $e')),
        );
      }
    }
  }

  void _showRatingDialog(
      BuildContext context, OrderModel order, String currentUid) {
    double selectedRating = 0;
    final _reviewCtrl = TextEditingController();
    final ratedUserId =
        widget.isSeller ? order.buyerId : order.sellerId;
    final ratedName = widget.isSeller
        ? (order.buyerName.isNotEmpty ? order.buyerName : order.clientName)
        : (order.sellerName.isNotEmpty ? order.sellerName : order.clientName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          title: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star,
                    color: Color(0xFFF59E0B), size: 32),
              ),
              const SizedBox(height: 12),
              const Text(
                'Rate Your Experience',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyBlue,
                    fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How was your experience working with $ratedName?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.blueGrey.shade600,
                    fontSize: 14,
                    height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1.0;
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedRating = starValue),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        selectedRating >= starValue
                            ? Icons.star
                            : Icons.star_outline,
                        color: const Color(0xFFF59E0B),
                        size: 38,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                selectedRating == 0
                    ? 'Tap to rate'
                    : _getRatingLabel(selectedRating.toInt()),
                style: TextStyle(
                  color: selectedRating == 0
                      ? Colors.blueGrey.shade400
                      : const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _reviewCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write a review (optional)',
                  hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueGrey.shade100),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Skip',
                  style: TextStyle(color: Colors.blueGrey.shade400)),
            ),
            ElevatedButton(
              onPressed: selectedRating == 0
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await context.read<OrderProvider>().saveRating(
                              orderId: order.id,
                              ratedUserId: ratedUserId,
                              raterId: currentUid,
                              rating: selectedRating,
                              isBuyerRating: !widget.isSeller,
                              reviewText: _reviewCtrl.text.trim(),
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Rating submitted! ⭐'),
                              backgroundColor: Color(0xFFF59E0B),
                            ),
                          );
                        }
                      } catch (e) {
                        // Silently fail — rating is optional
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor 😕';
      case 2:
        return 'Fair 🙂';
      case 3:
        return 'Good 👍';
      case 4:
        return 'Great 😊';
      case 5:
        return 'Excellent! 🌟';
      default:
        return '';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.arahPurple.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive
                  ? Icons.assignment_outlined
                  : Icons.assignment_turned_in_outlined,
              size: 36,
              color: AppTheme.arahPurple.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isActive ? 'No active orders' : 'No completed orders',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isActive
                ? (widget.isSeller
                    ? 'Tasks assigned to you will appear here'
                    : 'Assign a seller in chat to create an order')
                : 'Completed orders will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blueGrey.shade400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

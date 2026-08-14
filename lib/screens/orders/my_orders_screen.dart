import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/bottom_nav_bar.dart';
import '../../provider/order_provider.dart';
import '../../provider/user_provider.dart';
import '../chat/chat_screen.dart';
import 'order_detail_screen.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
appBar: AppBar(
  automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,
        title: Text(
          widget.isSeller ? 'My Work' : 'My Orders',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
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
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).dividerColor,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                isActive = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.colorsOf(context).chipSelectedBackground
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.colorsOf(context).shadow,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: Text(
                'Pending',
                style: TextStyle(
                  color: isActive
                      ? AppTheme.colorsOf(context).chipSelectedText
                      : Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color,
                  fontWeight: isActive
                      ? FontWeight.bold
                      : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                isActive = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: !isActive
                    ? AppTheme.colorsOf(context).chipSelectedBackground
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: !isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.colorsOf(context).shadow,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: Text(
                'Completed',
                style: TextStyle(
                  color: !isActive
                      ? AppTheme.colorsOf(context).chipSelectedText
                      : Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color,
                  fontWeight: !isActive
                      ? FontWeight.bold
                      : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
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
                  : orderProvider.hasError
                      ? _buildErrorState(orderProvider)
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
            color: isSelected ? Theme.of(context).cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.colorsOf(context).shadow,
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
                color: isSelected
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).textTheme.bodyMedium?.color,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.colorsOf(context).shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => _openOrderDetail(context, order),
            child: Padding(
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
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
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _buildStatusBadge(order.status),
                  ],
                ),
                if (order.status == 'InEscrow' ||
                    order.status == 'Delivered' ||
                    order.status == 'AwaitingPayment') ...[
                  const SizedBox(height: 10),
                  _buildCommissionHint(context, order),
                ],
              ],
            ),
            ),
          ),
          // Action Buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
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

  void _openOrderDetail(BuildContext context, OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(order: order, isSeller: widget.isSeller),
      ),
    );
  }

  Widget _buildCommissionHint(BuildContext context, OrderModel order) {
    final colors = AppTheme.colorsOf(context);
    return Row(
      children: [
        Icon(Icons.lock_outline, size: 13, color: colors.secondaryText),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            widget.isSeller
                ? 'You receive ${formatCurrency(order.sellerNetAmount)} after 9% commission'
                : 'Seller receives ${formatCurrency(order.sellerNetAmount)} (9% platform fee)',
            style: TextStyle(fontSize: 11, color: colors.secondaryText),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      BuildContext context, OrderModel order, String currentUid) {
    final colors = AppTheme.colorsOf(context);

    // ── Final states ──────────────────────────────────────────────
    if (order.status == 'Completed') {
      final hasRated = widget.isSeller ? order.ratedBySeller : order.ratedByBuyer;
      return Row(
        children: [
          Expanded(
            child: _actionButton(
              label: 'Chat',
              icon: Icons.chat_bubble_outline,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.navyBlue,
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
                color: colors.warning,
                onPressed: () => _showRatingDialog(context, order, currentUid),
              ),
            ),
          ],
        ],
      );
    }

    if (order.status == 'Refunded' || order.status == 'Rejected') {
      return _actionButton(
        label: 'View Details',
        icon: Icons.receipt_long_outlined,
        color: colors.secondaryText,
        onPressed: () => _openOrderDetail(context, order),
        outlined: true,
      );
    }

    // ── Request/approval stage ───────────────────────────────────
    if (order.status == 'PendingApproval') {
      if (widget.isSeller) {
        return Row(
          children: [
            Expanded(
              child: _actionButton(
                label: 'Reject',
                icon: Icons.close,
                color: colors.error,
                onPressed: () => context.read<OrderProvider>().rejectOrder(order.id),
                outlined: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionButton(
                label: 'Accept',
                icon: Icons.check,
                color: colors.success,
                onPressed: () => context.read<OrderProvider>().acceptOrder(order.id),
              ),
            ),
          ],
        );
      }
      return SizedBox(
        width: double.infinity,
        child: _actionButton(
          label: 'Awaiting Your Approval',
          icon: Icons.hourglass_empty,
          color: colors.secondaryText,
          onPressed: () => _openOrderDetail(context, order),
          outlined: true,
        ),
      );
    }

    // ── Payment stage ─────────────────────────────────────────────
    if (order.status == 'AwaitingPayment') {
      if (widget.isSeller) {
        return SizedBox(
          width: double.infinity,
          child: _actionButton(
            label: 'Waiting for Payment...',
            icon: Icons.hourglass_empty,
            color: colors.secondaryText,
            onPressed: () => _openOrderDetail(context, order),
            outlined: true,
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: _actionButton(
          label: 'Pay ${order.price} to Fund Escrow',
          icon: Icons.lock_outline,
          color: AppTheme.arahPurple,
          onPressed: () => _openOrderDetail(context, order),
        ),
      );
    }

    // ── Escrow (work in progress) ───────────────────────────────
    if (order.status == 'InEscrow') {
      if (widget.isSeller) {
        return Row(
          children: [
            Expanded(
              child: _actionButton(
                label: 'Chat',
                icon: Icons.chat_bubble_outline,
                color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.navyBlue,
                onPressed: () => _openChat(context, order, currentUid),
                outlined: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionButton(
                label: 'Mark Delivered',
                icon: Icons.local_shipping_outlined,
                color: colors.warning,
                onPressed: () => _openOrderDetail(context, order),
              ),
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(
            child: _actionButton(
              label: 'Chat',
              icon: Icons.chat_bubble_outline,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.colorsOf(context).mainText,
              onPressed: () => _openChat(context, order, currentUid),
              outlined: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              label: 'Escrow Held',
              icon: Icons.lock_outline,
              color: colors.info,
              onPressed: () => _openOrderDetail(context, order),
              outlined: true,
            ),
          ),
        ],
      );
    }

    // ── Delivered — awaiting buyer approval ─────────────────────
    if (order.status == 'Delivered') {
      if (widget.isSeller) {
        return SizedBox(
          width: double.infinity,
          child: _actionButton(
            label: 'Awaiting Buyer Approval',
            icon: Icons.hourglass_empty,
            color: colors.secondaryText,
            onPressed: () => _openOrderDetail(context, order),
            outlined: true,
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: _actionButton(
          label: 'Review & Release Payment',
          icon: Icons.check_circle_outline,
          color: colors.success,
          onPressed: () => _openOrderDetail(context, order),
        ),
      );
    }

    // Fallback
    return _actionButton(
      label: 'View Details',
      icon: Icons.chevron_right,
      color: AppTheme.arahPurple,
      onPressed: () => _openOrderDetail(context, order),
      outlined: true,
    );
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
    final colors = AppTheme.colorsOf(context);
    Color badgeColor;
    IconData? badgeIcon;
    String label = status;
    switch (status) {
      case 'Completed':
        badgeColor = colors.success;
        label = 'Released';
        badgeIcon = Icons.check_circle_outline;
        break;
      case 'Pending':
        badgeColor = Theme.of(context).colorScheme.primary;
        break;
      case 'PendingApproval':
        badgeColor = colors.warning;
        label = 'Pending Approval';
        badgeIcon = Icons.hourglass_empty;
        break;
      case 'AwaitingPayment':
        badgeColor = colors.warning;
        label = 'Awaiting Payment';
        badgeIcon = Icons.payment_outlined;
        break;
      case 'InEscrow':
        badgeColor = colors.info;
        label = 'In Escrow';
        badgeIcon = Icons.lock_outline;
        break;
      case 'Delivered':
        badgeColor = colors.warning;
        label = 'Delivered';
        badgeIcon = Icons.local_shipping_outlined;
        break;
      case 'Refunded':
        badgeColor = colors.error;
        label = 'Refunded';
        badgeIcon = Icons.replay_outlined;
        break;
      case 'Rejected':
        badgeColor = colors.error;
        badgeIcon = Icons.cancel_outlined;
        break;
      default:
        badgeColor = colors.secondaryText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeIcon != null) ...[
            Icon(badgeIcon, size: 12, color: badgeColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
                  color: AppTheme.colorsOf(context).warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star,
                    color: AppTheme.colorsOf(context).warning, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                'Rate Your Experience',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
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
                    color: Theme.of(context).textTheme.bodyMedium?.color,
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
                        color: AppTheme.colorsOf(context).warning,
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
                      ? Theme.of(context).textTheme.bodyMedium?.color
                      : AppTheme.colorsOf(context).warning,
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
                  hintStyle: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 14),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.colorsOf(context).warning),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Skip',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color)),
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
                            SnackBar(
                              content: const Text('Rating submitted! ⭐'),
                              backgroundColor: AppTheme.colorsOf(context).warning,
                            ),
                          );
                        }
                      } catch (e) {
                        // Silently fail — rating is optional
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colorsOf(context).warning,
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
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
              color: Theme.of(context).textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(OrderProvider orderProvider) {
    final colors = AppTheme.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 12),
            Text(
              "Couldn't load orders",
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Check your connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: orderProvider.retry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.arahPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app/theme/app_theme.dart';
import '../../provider/order_provider.dart';
import '../../provider/user_provider.dart';
import '../chat/chat_screen.dart';

/// Full payment & escrow view for a single order.
///
/// Covers the whole lifecycle: request -> payment -> escrow (held) ->
/// delivery -> buyer approval -> released (or refunded), with the 9%
/// platform commission always broken out for both buyer and seller.
class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  final bool isSeller;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.isSeller,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _busy = false;

  OrderModel get order => widget.order;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final currentUid = context.watch<UserProvider>().uid;

    // Keep this screen's data live: pull the freshest copy of this order
    // out of the provider if it's still in one of the lists.
    final provider = context.watch<OrderProvider>();
    final liveOrder = [
      ...provider.activeOrders,
      ...provider.completedOrders,
    ].firstWhere((o) => o.id == order.id, orElse: () => order);

    final counterpartyName = widget.isSeller
        ? (liveOrder.buyerName.isNotEmpty ? liveOrder.buyerName : liveOrder.clientName)
        : (liveOrder.sellerName.isNotEmpty ? liveOrder.sellerName : liveOrder.clientName);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          'Order Details',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildHeaderCard(context, liveOrder, counterpartyName),
            const SizedBox(height: 16),
            _buildStatusTimeline(context, liveOrder),
            const SizedBox(height: 16),
            _buildPaymentBreakdownCard(context, liveOrder, colors),
            if (liveOrder.isRefunded) ...[
              const SizedBox(height: 16),
              _buildRefundCard(context, liveOrder, colors),
            ],
            const SizedBox(height: 16),
            _buildEscrowNoticeCard(context, liveOrder, colors),
            const SizedBox(height: 24),
            _buildActions(context, liveOrder, currentUid, counterpartyName),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeaderCard(
      BuildContext context, OrderModel o, String counterpartyName) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  o.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              _statusChip(context, o.status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.arahPurple.withOpacity(0.1),
                child: Text(
                  counterpartyName.isNotEmpty
                      ? counterpartyName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppTheme.arahPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isSeller ? 'Buyer' : 'Seller',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.colorsOf(context).secondaryText,
                      ),
                    ),
                    Text(
                      counterpartyName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                o.price,
                style: const TextStyle(
                  color: AppTheme.arahPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Status timeline ──────────────────────────────────────────────────

  Widget _buildStatusTimeline(BuildContext context, OrderModel o) {
    final colors = AppTheme.colorsOf(context);

    if (o.isRejected) return const SizedBox.shrink();

    final paid = o.fundsHeld || o.isCompleted || o.isRefunded;

    final steps = <_TimelineStep>[
      _TimelineStep('Requested', true, o.isPendingApproval),
      _TimelineStep(
        'Payment',
        paid,
        o.isAwaitingPayment,
      ),
      _TimelineStep(
        o.isRefunded ? 'Refunded' : 'Escrow (Held)',
        paid,
        o.isInEscrow,
      ),
      _TimelineStep(
        'Delivered',
        o.isDelivered || o.isCompleted,
        o.isDelivered,
      ),
      _TimelineStep(
        'Released',
        o.isCompleted,
        false,
      ),
    ];

    // If refunded, cut the timeline short after the escrow/refund step.
    final visibleSteps = o.isRefunded ? steps.sublist(0, 3) : steps;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: List.generate(visibleSteps.length, (i) {
          final step = visibleSteps[i];
          final isLast = i == visibleSteps.length - 1;
          final dotColor = step.done
              ? (o.isRefunded && step.label == 'Refunded'
                  ? colors.error
                  : colors.success)
              : (step.active ? colors.warning : colors.secondaryText.withOpacity(0.3));
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox()
                          : Container(height: 2, color: dotColor.withOpacity(step.done ? 0.6 : 0.2)),
                    ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                      child: step.done
                          ? const Icon(Icons.check, size: 10, color: Colors.white)
                          : null,
                    ),
                    Expanded(
                      child: isLast
                          ? const SizedBox()
                          : Container(height: 2, color: Colors.transparent),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  step.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: step.active ? FontWeight.bold : FontWeight.w500,
                    color: step.done || step.active
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : colors.secondaryText,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Payment breakdown ────────────────────────────────────────────────

  Widget _buildPaymentBreakdownCard(
      BuildContext context, OrderModel o, AppColors colors) {
    final showReleased = o.isCompleted;
    final showPending = !o.isCompleted && !o.isRefunded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 18, color: colors.secondaryText),
              const SizedBox(width: 8),
              Text(
                'Payment breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _breakdownRow(context, 'Order amount', formatCurrency(o.amountValue)),
          const SizedBox(height: 8),
          _breakdownRow(
            context,
            'Platform commission (9%)',
            '- ${formatCurrency(o.commissionAmount)}',
            valueColor: colors.error,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Theme.of(context).dividerColor),
          ),
          _breakdownRow(
            context,
            widget.isSeller ? 'You receive' : 'Seller receives',
            formatCurrency(o.sellerNetAmount),
            bold: true,
          ),
          if (showPending) ...[
            const SizedBox(height: 12),
            Text(
              widget.isSeller
                  ? 'This is what you\'ll be paid once the buyer approves and releases the payment.'
                  : 'The seller receives this amount after the 9% platform commission is deducted from your payment.',
              style: TextStyle(fontSize: 12, color: colors.secondaryText, height: 1.4),
            ),
          ],
          if (showReleased) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.successBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: colors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isSeller
                          ? '${formatCurrency(o.sellerNetAmount)} released to your account${o.releasedAt != null ? ' on ${DateFormat('d MMM, h:mm a').format(o.releasedAt!)}' : ''}.'
                          : 'Payment released to the seller${o.releasedAt != null ? ' on ${DateFormat('d MMM, h:mm a').format(o.releasedAt!)}' : ''}.',
                      style: TextStyle(
                          fontSize: 12,
                          color: colors.success,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _breakdownRow(BuildContext context, String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: bold
                ? Theme.of(context).textTheme.bodyLarge?.color
                : AppTheme.colorsOf(context).secondaryText,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ??
                (bold
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).textTheme.bodyMedium?.color),
          ),
        ),
      ],
    );
  }

  // ── Refund info ──────────────────────────────────────────────────────

  Widget _buildRefundCard(BuildContext context, OrderModel o, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.error.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.replay_circle_filled_outlined, color: colors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Refunded — ${formatCurrency(o.amountValue)} returned',
                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.error),
                ),
                if (o.refundReason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(o.refundReason,
                      style: TextStyle(fontSize: 12, color: colors.error.withOpacity(0.85))),
                ],
                if (o.refundedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d MMM yyyy, h:mm a').format(o.refundedAt!),
                    style: TextStyle(fontSize: 11, color: colors.secondaryText),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Escrow status notice ─────────────────────────────────────────────

  Widget _buildEscrowNoticeCard(BuildContext context, OrderModel o, AppColors colors) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (o.status) {
      case OrderStatus.pendingApproval:
        icon = Icons.hourglass_top;
        color = colors.warning;
        title = 'Awaiting request approval';
        subtitle = widget.isSeller
            ? 'The buyer needs to accept your request before payment can be made.'
            : 'Review this request and accept or reject it from your Orders list.';
        break;
      case OrderStatus.awaitingPayment:
        icon = Icons.payment_outlined;
        color = colors.warning;
        title = 'Waiting for payment';
        subtitle = widget.isSeller
            ? 'The buyer has accepted — waiting for them to fund escrow before you start work.'
            : 'Fund escrow to confirm this order. The seller will start once payment is held.';
        break;
      case OrderStatus.inEscrow:
        icon = Icons.lock_outline;
        color = colors.info;
        title = 'Funds held in escrow';
        subtitle =
            'Payment is securely held and will only be released to the seller once the buyer approves the delivered work.';
        break;
      case OrderStatus.delivered:
        icon = Icons.local_shipping_outlined;
        color = colors.warning;
        title = 'Delivered — awaiting approval';
        subtitle = widget.isSeller
            ? 'The buyer has been notified. Funds stay in escrow until they approve.'
            : 'Review the delivered work, then approve to release payment to the seller.';
        break;
      case OrderStatus.completed:
        icon = Icons.verified_outlined;
        color = colors.success;
        title = 'Payment released';
        subtitle = 'This order is complete and funds have been released.';
        break;
      case OrderStatus.refunded:
        icon = Icons.undo_outlined;
        color = colors.error;
        title = 'Order refunded';
        subtitle = 'Escrowed funds were returned to the buyer.';
        break;
      case OrderStatus.rejected:
        icon = Icons.cancel_outlined;
        color = colors.error;
        title = 'Request rejected';
        subtitle = 'This request was declined before any payment was made.';
        break;
      default:
        icon = Icons.info_outline;
        color = colors.secondaryText;
        title = o.status;
        subtitle = '';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12.5, color: colors.secondaryText, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Widget _buildActions(BuildContext context, OrderModel o, String currentUid,
      String counterpartyName) {
    final colors = AppTheme.colorsOf(context);
    final buttons = <Widget>[];

    if (o.isPendingApproval && widget.isSeller) {
      buttons.add(_primaryButton(
        context,
        label: 'Waiting for buyer to accept',
        icon: Icons.hourglass_empty,
        color: colors.secondaryText,
        onPressed: null,
      ));
    }

    if (o.isAwaitingPayment) {
      if (widget.isSeller) {
        buttons.add(_primaryButton(
          context,
          label: 'Waiting for buyer payment',
          icon: Icons.hourglass_empty,
          color: colors.secondaryText,
          onPressed: null,
        ));
      } else {
        buttons.add(_primaryButton(
          context,
          label: 'Pay ${formatCurrency(o.amountValue)} to Fund Escrow',
          icon: Icons.lock_outline,
          color: AppTheme.arahPurple,
          onPressed: _busy ? null : () => _showPaymentSheet(context, o),
        ));
      }
    }

    if (o.isInEscrow) {
      if (widget.isSeller) {
        buttons.add(_primaryButton(
          context,
          label: 'Mark as Delivered',
          icon: Icons.local_shipping_outlined,
          color: colors.warning,
          onPressed: _busy ? null : () => _confirmMarkDelivered(context, o),
        ));
      } else {
        buttons.add(_outlinedButton(
          context,
          label: 'Request Refund',
          icon: Icons.replay_outlined,
          color: colors.error,
          onPressed: _busy ? null : () => _showRefundDialog(context, o),
        ));
      }
    }

    if (o.isDelivered) {
      if (widget.isSeller) {
        buttons.add(_primaryButton(
          context,
          label: 'Waiting for buyer approval',
          icon: Icons.hourglass_empty,
          color: colors.secondaryText,
          onPressed: null,
        ));
      } else {
        buttons.add(_primaryButton(
          context,
          label: 'Approve & Release Payment',
          icon: Icons.check_circle_outline,
          color: colors.success,
          onPressed: _busy ? null : () => _confirmRelease(context, o),
        ));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_outlinedButton(
          context,
          label: 'Request Refund Instead',
          icon: Icons.replay_outlined,
          color: colors.error,
          onPressed: _busy ? null : () => _showRefundDialog(context, o),
        ));
      }
    }

    if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 10));

    buttons.add(_outlinedButton(
      context,
      label: 'Chat with $counterpartyName',
      icon: Icons.chat_bubble_outline,
      color: Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.navyBlue,
      onPressed: () => _openChat(context, o, currentUid),
    ));

    return Column(children: buttons);
  }

  Widget _primaryButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _outlinedButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final colors = AppTheme.colorsOf(context);
    Color color;
    String label = status;
    switch (status) {
      case OrderStatus.completed:
        color = colors.success;
        label = 'Released';
        break;
      case OrderStatus.pendingApproval:
        color = colors.warning;
        label = 'Pending Approval';
        break;
      case OrderStatus.awaitingPayment:
        color = colors.warning;
        label = 'Awaiting Payment';
        break;
      case OrderStatus.inEscrow:
        color = colors.info;
        label = 'In Escrow';
        break;
      case OrderStatus.delivered:
        color = colors.warning;
        label = 'Delivered';
        break;
      case OrderStatus.refunded:
        color = colors.error;
        label = 'Refunded';
        break;
      case OrderStatus.rejected:
        color = colors.error;
        break;
      default:
        color = colors.secondaryText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ── Action handlers ───────────────────────────────────────────────────

  void _openChat(BuildContext context, OrderModel o, String currentUid) {
    final otherUserId = widget.isSeller ? o.buyerId : o.sellerId;
    final sorted = [currentUid, otherUserId]..sort();
    final chatId = o.chatId.isNotEmpty ? o.chatId : '${sorted[0]}_${sorted[1]}';
    final counterpartyName = widget.isSeller
        ? (o.buyerName.isNotEmpty ? o.buyerName : o.clientName)
        : (o.sellerName.isNotEmpty ? o.sellerName : o.clientName);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: otherUserId,
          otherUserName: counterpartyName,
          taskId: o.taskId,
          taskTitle: o.title,
          taskPrice: o.price,
          isBuyer: !widget.isSeller,
        ),
      ),
    );
  }

  Future<void> _showPaymentSheet(BuildContext context, OrderModel o) async {
    final colors = AppTheme.colorsOf(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: BoxDecoration(
            color: Theme.of(ctx).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.lock_outline, color: AppTheme.arahPurple),
                  const SizedBox(width: 8),
                  Text(
                    'Fund Escrow',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(ctx).textTheme.bodyLarge?.color),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _breakdownRow(ctx, 'Order amount', formatCurrency(o.amountValue)),
              const SizedBox(height: 8),
              _breakdownRow(
                ctx,
                'Platform commission (9%)',
                formatCurrency(o.commissionAmount),
                valueColor: colors.secondaryText,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: Theme.of(ctx).dividerColor),
              ),
              _breakdownRow(ctx, 'You pay', formatCurrency(o.amountValue), bold: true),
              const SizedBox(height: 8),
              Text(
                'This amount will be held safely in escrow and only released to the seller once you approve the completed work.',
                style: TextStyle(fontSize: 12, color: colors.secondaryText, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.arahPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Pay ${formatCurrency(o.amountValue)}'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    // Brief processing state so the escrow-hold action feels real.
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppTheme.arahPurple),
      ),
    );

    try {
      await context.read<OrderProvider>().payOrder(o.id);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.pop(context); // close processing dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment successful — funds held in escrow 🔒'),
            backgroundColor: AppTheme.colorsOf(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmMarkDelivered(BuildContext context, OrderModel o) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mark as Delivered?',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: const Text(
            'The buyer will be notified to review your work and approve the release of payment.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.colorsOf(context).warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Mark Delivered'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<OrderProvider>().markDelivered(o.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Marked as delivered. Waiting for buyer approval.'),
            backgroundColor: AppTheme.colorsOf(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRelease(BuildContext context, OrderModel o) async {
    final colors = AppTheme.colorsOf(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Approve & Release Payment?',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text(
          'This releases ${formatCurrency(o.sellerNetAmount)} to the seller (after 9% platform commission) and cannot be undone.',
          style: TextStyle(color: colors.secondaryText, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Release Payment'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<OrderProvider>().releaseOrder(o.id, o.taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment released. Order completed! 🎉'),
            backgroundColor: AppTheme.colorsOf(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRefundDialog(BuildContext context, OrderModel o) async {
    final colors = AppTheme.colorsOf(context);
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Request a Refund',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatCurrency(o.amountValue)} held in escrow will be returned to you and this task will be reopened for reassignment.',
              style: TextStyle(color: colors.secondaryText, height: 1.4, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context
          .read<OrderProvider>()
          .requestRefund(o.id, o.taskId, reason: reasonCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Refund processed. Task is back on the marketplace.'),
            backgroundColor: AppTheme.colorsOf(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _TimelineStep {
  final String label;
  final bool done;
  final bool active;
  _TimelineStep(this.label, this.done, this.active);
}

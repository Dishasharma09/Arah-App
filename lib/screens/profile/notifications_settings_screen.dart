import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme/app_theme.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _newMessages = true;
  bool _taskUpdates = true;
  bool _bidNotifications = true;
  bool _marketing = false;
  bool _orderStatus = true;
  bool _soundEnabled = true;

  static const _kNewMessages = 'notif_new_messages';
  static const _kTaskUpdates = 'notif_task_updates';
  static const _kBidNotif = 'notif_bids';
  static const _kMarketing = 'notif_marketing';
  static const _kOrderStatus = 'notif_order_status';
  static const _kSound = 'notif_sound';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _newMessages = prefs.getBool(_kNewMessages) ?? true;
      _taskUpdates = prefs.getBool(_kTaskUpdates) ?? true;
      _bidNotifications = prefs.getBool(_kBidNotif) ?? true;
      _marketing = prefs.getBool(_kMarketing) ?? false;
      _orderStatus = prefs.getBool(_kOrderStatus) ?? true;
      _soundEnabled = prefs.getBool(_kSound) ?? true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Activity'),
            _buildCard([
              _buildToggle(
                'New Messages',
                'Get notified when someone messages you',
                Icons.chat_bubble_outline,
                _newMessages,
                (val) {
                  setState(() => _newMessages = val);
                  _savePref(_kNewMessages, val);
                },
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _buildToggle(
                'Task Updates',
                'Status changes on your posted tasks',
                Icons.assignment_outlined,
                _taskUpdates,
                (val) {
                  setState(() => _taskUpdates = val);
                  _savePref(_kTaskUpdates, val);
                },
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _buildToggle(
                'Bid Notifications',
                'When someone bids on your task',
                Icons.gavel_outlined,
                _bidNotifications,
                (val) {
                  setState(() => _bidNotifications = val);
                  _savePref(_kBidNotif, val);
                },
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _buildToggle(
                'Order Status',
                'Updates on your active orders',
                Icons.local_shipping_outlined,
                _orderStatus,
                (val) {
                  setState(() => _orderStatus = val);
                  _savePref(_kOrderStatus, val);
                },
              ),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('Sound & Display'),
            _buildCard([
              _buildToggle(
                'Sound',
                'Play sound for notifications',
                Icons.volume_up_outlined,
                _soundEnabled,
                (val) {
                  setState(() => _soundEnabled = val);
                  _savePref(_kSound, val);
                },
              ),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('Marketing'),
            _buildCard([
              _buildToggle(
                'Tips & Promotions',
                'Deals, announcements and platform updates',
                Icons.local_offer_outlined,
                _marketing,
                (val) {
                  setState(() => _marketing = val);
                  _savePref(_kMarketing, val);
                },
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.arahPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppTheme.arahPurple),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.arahPurple,
          ),
        ],
      ),
    );
  }
}

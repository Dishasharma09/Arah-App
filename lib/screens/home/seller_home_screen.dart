import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/bottom_nav_bar.dart';
import '../../app/widgets/smart_match_icon.dart';
import '../../provider/home_provider.dart';
import '../../provider/user_provider.dart';
import '../../models/user_model.dart';
import '../notifications/notifications_screen.dart';
import '../matching/smart_matches_screen.dart';
import '../../provider/notification_provider.dart';
import '../../provider/order_provider.dart';
import '../../models/task_model.dart';
import '../../services/firestore_service.dart';
import '../../data/categories.dart';
import 'home_screen.dart';
import 'task_detail_screen.dart';
import '../chat/chat_screen.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  String _selectedCategory = 'All';
  String? _selectedSubCategory;
  String _searchQuery = '';
  double? _maxBudget;
  List<UserModel> _users = [];

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final homeProvider = context.watch<HomeProvider>();
    final profileImage = userProvider.profileImageFile;
    final role = userProvider.role;
    final canSwitchToBuyer = role == 'Both';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Filter from the real Firestore tasks (already excludes own tasks)
    List<TaskModel> tasks = homeProvider.allTasks
        .where((t) => !userProvider.isUserBlocked(t.buyerId))
        .toList();
    if (_selectedCategory != 'All') {
      tasks = tasks.where((t) => t.category == _selectedCategory).toList();

      if (_selectedSubCategory != null) {
        tasks = tasks
            .where((t) => t.subCategory == _selectedSubCategory)
            .toList();
      }
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();

      tasks = tasks.where((t) {
        return t.title.toLowerCase().contains(query) ||
            t.buyerName.toLowerCase().contains(query) ||
            t.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leadingWidth: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(8),
                image: profileImage != null
                    ? DecorationImage(
                        image: FileImage(profileImage),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profileImage == null
                  ? Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.asset(
                        "assets/images/Arah_bg.png",
                        fit: BoxFit.contain,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              "Find Work",
              style: TextStyle(
                color: Theme.of(context).textTheme.headlineLarge?.color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const SmartMatchIcon(size: 24),
            tooltip: 'Smart Matches',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SmartMatchesScreen(),
                ),
              );
            },
          ),
          // Notifications icon — kept identical to BuyerHomeScreen's so the
          // bell icon and unread indicator look the same in both modes.
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              final unreadCount = notificationProvider.unreadCount;

              return IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none),
                    if (unreadCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: unreadCount > 9
                                ? BoxShape.rectangle
                                : BoxShape.circle,
                            borderRadius: unreadCount > 9
                                ? BorderRadius.circular(8)
                                : null,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          if (canSwitchToBuyer)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ModeToggle(isBuyerMode: false),
            ),
        ],
      ),
      bottomNavigationBar: const ArahBottomNavBar(
        currentIndex: 0,
        isSeller: true,
      ),
      body: SafeArea(
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  onChanged: (value) async {
                    setState(() {
                      _searchQuery = value;
                    });

                    if (value.trim().isNotEmpty) {
                      final blockedIds =
                          context.read<UserProvider>().blockedUserIds;
                      final users = await FirestoreService().searchUsers(
                        value.trim(),
                      );
                      setState(() {
                        _users = users
                            .where((u) => !blockedIds.contains(u.id))
                            .toList();
                      });
                    } else {
                      setState(() {
                        _users.clear();
                      });
                    }
                  },

                  decoration: InputDecoration(
                    hintText: "Search users or tasks...",
                    hintStyle: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).hintColor,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Theme.of(context).hintColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _users.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              if (_users.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Theme.of(context).cardColor,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user.name[0].toUpperCase()),
                        ),
                        title: Text(user.name),
                        subtitle: Text(user.role),
                      );
                    },
                  ),
                ),

              // Category filter
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.only(bottom: 12),
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildBudgetChip(context),

                    ...[
                      'All',
                      'Design',
                      'Development',
                      'Writing',
                      'Video',
                      'Marketing',
                    ].map((cat) => _buildCategoryChip(context, cat)),
                  ],
                ),
              ),
              if (_selectedCategory != 'All' &&
                  subCategoriesFor(_selectedCategory).isNotEmpty)
                Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.only(bottom: 12.0),
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: subCategoriesFor(_selectedCategory)
                        .map((sub) => _buildSubCategoryChip(context, sub))
                        .toList(),
                  ),
                ),
              // Task count info bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Text(
                      '${tasks.length} task${tasks.length == 1 ? '' : 's'} available',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (homeProvider.isLoadingTasks)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              // Task list
              Expanded(
                child: homeProvider.isLoadingTasks && tasks.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : tasks.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        color: theme.colorScheme.primary,
                        onRefresh: () async {
                          final uid = context.read<UserProvider>().uid;
                          context.read<HomeProvider>().subscribeToOpenTasks(
                            excludeUserId: uid,
                          );
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            return _buildSellerCard(context, tasks[index]);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBudgetModal(BuildContext context) {
    final theme = Theme.of(context);
    double currentBudget = _maxBudget ?? 5000;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Set Maximum Budget",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "₹${currentBudget.toInt()}",
                    style: TextStyle(
                      fontSize: 20,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Slider(
                    value: currentBudget,
                    min: 500,
                    max: 50000,
                    divisions: 99,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (value) {
                      setModalState(() {
                        currentBudget = value;
                      });
                    },
                  ),

                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _maxBudget = currentBudget;
                      });

                      Navigator.pop(context);
                    },
                    child: const Text("Apply Filter"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBudgetChip(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showBudgetModal(context),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _maxBudget != null
              ? AppTheme.colorsOf(context).chipSelectedBackground
              : theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Row(
          children: [
            Icon(
              Icons.filter_alt_outlined,
              size: 16,
              color: _maxBudget != null
                  ? AppTheme.colorsOf(context).chipSelectedText
                  : theme.textTheme.bodyMedium?.color,
            ),
            const SizedBox(width: 6),
            Text(
              _maxBudget != null ? "Up to ₹${_maxBudget!.toInt()}" : "Budget",
              style: TextStyle(
                color: _maxBudget != null
                    ? AppTheme.colorsOf(context).chipSelectedText
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryChip(BuildContext context, String title) {
    final isActive = _selectedSubCategory == title;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubCategory = isActive ? null : title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive
              ? const Color.fromARGB(255, 18, 30, 44)
              : theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : theme.textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, String cat) {
    final isActive = _selectedCategory == cat;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = cat;
          _selectedSubCategory = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.colorsOf(context).chipSelectedBackground
              : Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          cat,
          style: TextStyle(
            color: isActive
                ? AppTheme.colorsOf(context).chipSelectedText
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSellerCard(BuildContext context, TaskModel task) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(task: task, isSeller: true),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.title,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      task.price,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      task.budgetType,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (task.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: task.tags.map((tag) => _buildTag(tag)).toList(),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,

                  color: Theme.of(context).iconTheme.color,
                ),

                const SizedBox(width: 4),
                Text(
                  task.buyerName.isNotEmpty ? task.buyerName : 'Anonymous',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time,
                  size: 14,

                  color: Theme.of(context).iconTheme.color,
                ),
                const SizedBox(width: 4),
                Text(
                  task.postedTime.isNotEmpty ? task.postedTime : 'Open',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (task.orderTakerNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.colorsOf(context).successBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.colorsOf(context).success.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 16,
                      color: AppTheme.colorsOf(context).success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Takers',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.colorsOf(context).success,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.orderTakerNames.join(', '),
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _messageToBid(context, task),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text(
                  "Message to Bid",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _messageToBid(BuildContext context, TaskModel task) async {
    final userProvider = context.read<UserProvider>();
    final currentUid = userProvider.uid;
    final otherUid = task.buyerId;

    if (otherUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start a chat: task has no buyer ID.'),
        ),
      );
      return;
    }

    if (otherUid == currentUid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('This is your own task.')));
      return;
    }

    try {
      final firestoreService = FirestoreService();
      final chatId = await firestoreService.createOrGetChatRoom(
        currentUid,
        otherUid,
        taskId: task.id,
      );
      final otherInfo = await firestoreService.getUserBasicInfo(otherUid);

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: otherUid,
            otherUserName: otherInfo['name'] ?? task.buyerName,
            taskId: task.id,
            taskTitle: task.title,
            taskPrice: task.price,
            isBuyer: false, // Seller cannot assign
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open chat: $e')));
      }
    }
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.colorsOf(context).chipSelectedBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.colorsOf(context).border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.colorsOf(context)
              .chipSelectedText
              .withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.work_outline,
              size: 36,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New tasks will appear here.\nPull down to refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.colorsOf(context).secondaryText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reuse the _ModeToggle from home_screen.dart
class _ModeToggle extends StatelessWidget {
  final bool isBuyerMode;
  const _ModeToggle({required this.isBuyerMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleChip(context, 'Buyer', isBuyerMode, () async {
            if (!isBuyerMode) {
              await context.read<UserProvider>().switchMode('Buyer');
              final uid = context.read<UserProvider>().uid;
              context.read<HomeProvider>().subscribeToOpenTasks(
                excludeUserId: uid,
              );
              context.read<OrderProvider>().subscribeToOrders(
                uid,
                isSeller: false,
              );
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const BuyerHomeScreen()),
                  (route) => false,
                );
              }
            }
          }),
          _toggleChip(context, 'Seller', !isBuyerMode, () async {
            if (isBuyerMode) {
              await context.read<UserProvider>().switchMode('Seller');
              final uid = context.read<UserProvider>().uid;
              context.read<HomeProvider>().subscribeToOpenTasks(
                excludeUserId: uid,
              );
              context.read<OrderProvider>().subscribeToOrders(
                uid,
                isSeller: true,
              );
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SellerHomeScreen()),
                  (route) => false,
                );
              }
            }
          }),
        ],
      ),
    );
  }

  Widget _toggleChip(
    BuildContext context,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? theme.colorScheme.onPrimary
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
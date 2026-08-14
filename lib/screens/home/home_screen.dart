import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/bottom_nav_bar.dart';
import '../../app/widgets/smart_match_icon.dart';
import '../request/create_request_screen.dart';
import 'seller_home_screen.dart';
import 'task_detail_screen.dart';
import '../chat/chat_screen.dart';
import '../../provider/home_provider.dart';
import '../notifications/notifications_screen.dart';
import '../matching/smart_matches_screen.dart';
import '../../provider/notification_provider.dart';
import '../../provider/user_provider.dart';
import '../../provider/order_provider.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../data/categories.dart';
import 'dart:async';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  List<UserModel> _users = [];

  Timer? _debounce;

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final userProvider = context.watch<UserProvider>();
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final profileImage = userProvider.profileImageFile;
    final filteredTasks = homeProvider.filteredTasks
        .where((t) => !userProvider.isUserBlocked(t.buyerId))
        .toList();
    final role = userProvider.role;
    final canSwitchToSeller = role == 'Both';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.appBarTheme.backgroundColor ??
            theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leadingWidth: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
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
            ),
            const SizedBox(width: 12),
            Text(
              "Discover",
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
          if (canSwitchToSeller)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ModeToggle(
                isBuyerMode: true,
              ),
            ),
        ],
      ),
      bottomNavigationBar:
          const ArahBottomNavBar(currentIndex: 0, isSeller: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateRequestScreen(),
            ),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: Icon(
          Icons.add,
          color: theme.colorScheme.onPrimary,
          size: 28,
        ),
      ),
      body: SafeArea(
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              Container(
                color: theme.scaffoldBackgroundColor,
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 16.0,
                  top: 4.0,
                ),
                child: TextField(
                  onChanged: (value) {
                    context.read<HomeProvider>().updateSearchQuery(value);

                    if (_debounce?.isActive ?? false) {
                      _debounce!.cancel();
                    }

                    _debounce = Timer(
                      const Duration(milliseconds: 400),
                      () async {
                        if (value.trim().isEmpty) {
                          if (!mounted) return;

                          setState(() {
                            _users.clear();
                          });

                          return;
                        }

                        final myUid = context.read<UserProvider>().uid;
                        final blockedIds =
                            context.read<UserProvider>().blockedUserIds;

                        final users =
                            await FirestoreService().searchUsers(value.trim());

                        if (!mounted) return;

                        setState(() {
                          _users = users
                              .where((u) =>
                                  u.id != myUid && !blockedIds.contains(u.id))
                              .toList();
                        });
                      },
                    );
                  },
                  decoration: InputDecoration(
                    hintText: "Search users or tasks...",
                    hintStyle: TextStyle(
                      color: Theme.of(context).iconTheme.color,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    suffixIcon: homeProvider.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: Theme.of(context).iconTheme.color),
                            onPressed: () {
                              context.read<HomeProvider>().updateSearchQuery('');
                              setState(() {
                                _users.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor,
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
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (user.photoUrl != null &&
                                  user.photoUrl!.isNotEmpty)
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: (user.photoUrl == null ||
                                  user.photoUrl!.isEmpty)
                              ? Text(user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?')
                              : null,
                        ),
                        title: Text(user.name),
                        subtitle: Text(user.role),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => _openChatWithUser(context, user),
                      );
                    },
                  ),
                ),
              Container(
                color: cardColor,
                padding: const EdgeInsets.only(bottom: 12.0),
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    GestureDetector(
                      onTap: () => _showBudgetModal(context),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: homeProvider.maxBudget != null
                              ? AppTheme.colorsOf(context).chipSelectedBackground
                              : Theme.of(context).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_alt_outlined,
                              size: 16,
                              color: homeProvider.maxBudget != null
                                  ? AppTheme.colorsOf(context).chipSelectedText
                                  : Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              homeProvider.maxBudget != null
                                  ? "Up to ₹${homeProvider.maxBudget!.toInt()}"
                                  : "Budget",
                              style: TextStyle(
                                color: homeProvider.maxBudget != null
                                    ? AppTheme.colorsOf(context).chipSelectedText
                                    : Theme.of(context).textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (homeProvider.maxBudget != null) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => context
                                    .read<HomeProvider>()
                                    .updateMaxBudget(null),
                                child: Icon(Icons.close,
                                    size: 14,
                                    color: AppTheme.colorsOf(context)
                                        .chipSelectedText),
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                    _buildCategoryChip(context, "All"),
                    ...mainCategories
                        .map((cat) => _buildCategoryChip(context, cat)),
                  ],
                ),
              ),
              if (homeProvider.selectedCategory != "All" &&
                  subCategoriesFor(homeProvider.selectedCategory).isNotEmpty)
                Container(
                  color: theme.scaffoldBackgroundColor,
                  padding: const EdgeInsets.only(bottom: 12.0),
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: subCategoriesFor(homeProvider.selectedCategory)
                        .map((sub) => _buildSubCategoryChip(context, sub))
                        .toList(),
                  ),
                ),
              Expanded(
                child: homeProvider.isLoadingTasks && filteredTasks.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(
                            color: theme.colorScheme.primary))
                    : filteredTasks.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            color: theme.colorScheme.primary,
                            onRefresh: () async {
                              final uid = context.read<UserProvider>().uid;
                              context
                                  .read<HomeProvider>()
                                  .subscribeToOpenTasks(excludeUserId: uid);
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              itemCount: filteredTasks.length,
                              itemBuilder: (context, index) {
                                return _buildTaskCard(
                                    context, filteredTasks[index]);
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

  Widget _buildTaskCard(BuildContext context, TaskModel task) {
    final currentUid = context.read<UserProvider>().uid;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(task: task, isSeller: false),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? []
              : [
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.category,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      task.price,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      task.budgetType,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (task.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: task.tags
                    .take(3)
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.colorsOf(context)
                                .chipSelectedBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppTheme.colorsOf(context).border),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.colorsOf(context)
                                  .chipSelectedText
                                  .withOpacity(0.7),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 14, color: Theme.of(context).iconTheme.color),
                const SizedBox(width: 6),
                Text(
                  task.postedTime.isNotEmpty ? task.postedTime : 'Just now',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                if (task.buyerName.isNotEmpty)
                  Text(
                    'by ${task.buyerName}',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            if (task.buyerId == currentUid &&
                task.orderTakerNames.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.colorsOf(context).successBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.colorsOf(context).success.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.people_alt_outlined,
                        size: 16, color: AppTheme.colorsOf(context).success),
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
                              color: AppTheme.colorsOf(context).success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openChatWithUser(BuildContext context, UserModel user) async {
    final myUid = context.read<UserProvider>().uid;
    final firestoreService = FirestoreService();
    final chatId = await firestoreService.createOrGetChatRoom(myUid, user.id);

    if (!context.mounted) return;
    setState(() {
      _users.clear();
    });
    context.read<HomeProvider>().updateSearchQuery('');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: user.id,
          otherUserName: user.name,
          isBuyer: true,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64, color: AppTheme.colorsOf(context).secondaryText),
          const SizedBox(height: 16),
          Text(
            'No tasks found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or post a task',
            style: TextStyle(
                fontSize: 14, color: Theme.of(context).iconTheme.color),
          ),
        ],
      ),
    );
  }

  void _showBudgetModal(BuildContext context) {
    final theme = Theme.of(context);
    double currentBudget = context.read<HomeProvider>().maxBudget ?? 5000.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: 250,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Set Maximum Budget",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Max Price:",
                          style: TextStyle(
                              color: AppTheme.colorsOf(context).secondaryText)),
                      Text(
                        "₹${currentBudget.toInt()}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: currentBudget,
                    min: 500,
                    max: 50000,
                    divisions: 99,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (val) {
                      setState(() {
                        currentBudget = val;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context
                            .read<HomeProvider>()
                            .updateMaxBudget(currentBudget);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Apply Filter"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryChip(BuildContext context, String title) {
    final homeProvider = context.watch<HomeProvider>();
    bool isActive = homeProvider.selectedCategory == title;

    return GestureDetector(
      onTap: () {
        context.read<HomeProvider>().selectCategory(title);
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
          title,
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

  /// Smaller chip for the second-level (sub-category) row. Tapping the
  /// active one again clears it, same as the main category chips.
  Widget _buildSubCategoryChip(BuildContext context, String title) {
    final homeProvider = context.watch<HomeProvider>();
    final isActive = homeProvider.selectedSubCategory == title;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        context.read<HomeProvider>().selectSubCategory(title);
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
          border: Border.all(
            color: isActive
                ? const Color(0xFF162B45)
                : AppTheme.colorsOf(context).border,
          ),
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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// Shared mode toggle for "Both" role users
class _ModeToggle extends StatelessWidget {
  final bool isBuyerMode;
  const _ModeToggle({required this.isBuyerMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleChip(context, 'Buyer', isBuyerMode, () async {
            if (!isBuyerMode) {
              await context.read<UserProvider>().switchMode('Buyer');
              final uid = context.read<UserProvider>().uid;
              context
                  .read<HomeProvider>()
                  .subscribeToOpenTasks(excludeUserId: uid);
              context
                  .read<OrderProvider>()
                  .subscribeToOrders(uid, isSeller: false);
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
              context
                  .read<HomeProvider>()
                  .subscribeToOpenTasks(excludeUserId: uid);
              context
                  .read<OrderProvider>()
                  .subscribeToOrders(uid, isSeller: true);
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
      BuildContext context, String label, bool isActive, VoidCallback onTap) {
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
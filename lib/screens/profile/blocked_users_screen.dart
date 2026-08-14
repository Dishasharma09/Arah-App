import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme/app_theme.dart';
import '../../provider/user_provider.dart';
import '../../services/firestore_service.dart';

/// Standalone management screen for everyone the current user has blocked.
/// Reachable from Settings → Privacy & Security → Blocked Users, so people
/// don't have to remember which chat a block happened in just to undo it.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUser {
  final String id;
  final String name;
  final String photoUrl;
  _BlockedUser({required this.id, required this.name, required this.photoUrl});
}

enum _LoadState { loading, loaded, error }

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _firestoreService = FirestoreService();
  _LoadState _state = _LoadState.loading;
  List<_BlockedUser> _blockedUsers = [];
  final Set<String> _unblockingIds = {}; // per-row spinner while unblocking

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);

    final uid = context.read<UserProvider>().uid;
    if (uid.isEmpty) {
      if (mounted) setState(() => _state = _LoadState.error);
      return;
    }

    try {
      final ids = await _firestoreService.getBlockedUserIds(uid);
      final users = <_BlockedUser>[];
      for (final id in ids) {
        final info = await _firestoreService.getUserBasicInfo(id);
        users.add(_BlockedUser(
          id: id,
          name: info['name'] ?? 'Unknown',
          photoUrl: info['photoUrl'] ?? '',
        ));
      }
      if (!mounted) return;
      setState(() {
        _blockedUsers = users;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      debugPrint('BlockedUsersScreen load error: $e');
      if (mounted) setState(() => _state = _LoadState.error);
    }
  }

  Future<void> _confirmUnblock(_BlockedUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unblock User?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          "You'll be able to message ${user.name} again after unblocking.",
          style: TextStyle(color: AppTheme.colorsOf(ctx).secondaryText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.colorsOf(ctx).secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.arahPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _unblockingIds.add(user.id));

    final userProvider = context.read<UserProvider>();
    try {
      await _firestoreService.unblockUser(
        blockerId: userProvider.uid,
        blockedId: user.id,
      );
      await userProvider.refreshBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blockedUsers.removeWhere((u) => u.id == user.id);
        _unblockingIds.remove(user.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} has been unblocked')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _unblockingIds.remove(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unblock failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        title: Text(
          'Blocked Users',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_state) {
      case _LoadState.loading:
        return Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        );

      case _LoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 44, color: AppTheme.colorsOf(context).error),
                const SizedBox(height: 12),
                Text(
                  "Couldn't load blocked users",
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Check your connection and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.colorsOf(context).secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _load,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );

      case _LoadState.loaded:
        if (_blockedUsers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block,
                      size: 48, color: AppTheme.colorsOf(context).secondaryText),
                  const SizedBox(height: 12),
                  Text(
                    "You haven't blocked anyone",
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Blocked users won\'t be able to message you, and you '
                    'won\'t see their tasks or messages.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.colorsOf(context).secondaryText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _blockedUsers.length + 1,
            separatorBuilder: (_, index) =>
                index == 0 ? const SizedBox.shrink() : Divider(height: 1, color: theme.dividerColor),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    '${_blockedUsers.length} blocked '
                    '${_blockedUsers.length == 1 ? 'user' : 'users'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.colorsOf(context).secondaryText,
                    ),
                  ),
                );
              }

              final user = _blockedUsers[index - 1];
              final isUnblocking = _unblockingIds.contains(user.id);

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.arahPurple.withOpacity(0.1),
                  backgroundImage:
                      user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                  child: user.photoUrl.isEmpty
                      ? Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AppTheme.arahPurple,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                title: Text(
                  user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                trailing: SizedBox(
                  height: 34,
                  child: OutlinedButton(
                    onPressed: isUnblocking ? null : () => _confirmUnblock(user),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.arahPurple,
                      side: const BorderSide(color: AppTheme.arahPurple),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: isUnblocking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.arahPurple),
                          )
                        : const Text('Unblock', style: TextStyle(fontSize: 12)),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}

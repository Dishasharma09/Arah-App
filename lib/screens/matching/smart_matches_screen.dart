import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme/app_theme.dart';
import '../../models/match_result_model.dart';
import '../../provider/match_provider.dart';
import '../../provider/user_provider.dart';

/// Smart Matching screen.
///
/// ── SPRINT 3 STATUS ──────────────────────────────────────────────────
/// Emmanuel has not provided the matching logic/API yet. This screen is
/// fully built (loading, empty, error and loaded states, correct
/// ordering by match score, pull-to-refresh) and ready to display real
/// data the moment [MatchProvider.backendAvailable] is flipped on and
/// wired to the real endpoint. Nothing here fabricates a match — while
/// the backend is unavailable this always renders the "coming soon"
/// empty state, never fake results.
class SmartMatchesScreen extends StatefulWidget {
  const SmartMatchesScreen({super.key});

  @override
  State<SmartMatchesScreen> createState() => _SmartMatchesScreenState();
}

class _SmartMatchesScreenState extends State<SmartMatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<UserProvider>().uid;
      if (uid.isNotEmpty) {
        context.read<MatchProvider>().loadMatches(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MatchProvider>();
    final colors = AppTheme.colorsOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          'Smart Matches',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.arahPurple,
          onRefresh: () async {
            final uid = context.read<UserProvider>().uid;
            if (uid.isNotEmpty) {
              await context.read<MatchProvider>().retry(uid);
            }
          },
          child: _buildBody(context, provider, colors),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, MatchProvider provider, AppColors colors) {
    switch (provider.status) {
      case MatchLoadStatus.loading:
        return ListView(
          // ListView (not Center) so pull-to-refresh still works on this state.
          children: const [
            SizedBox(height: 120),
            Center(
              child: CircularProgressIndicator(color: AppTheme.arahPurple),
            ),
            SizedBox(height: 16),
          ],
        );

      case MatchLoadStatus.error:
        return ListView(
          children: [
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: colors.error),
                  const SizedBox(height: 12),
                  Text(
                    "Couldn't load your matches",
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.errorMessage ??
                        'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.secondaryText, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final uid = context.read<UserProvider>().uid;
                      if (uid.isNotEmpty) {
                        context.read<MatchProvider>().retry(uid);
                      }
                    },
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
          ],
        );

      case MatchLoadStatus.empty:
        return ListView(
          children: [
            const SizedBox(height: 90),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.arahPurple.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 36,
                      color: AppTheme.arahPurple,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    MatchProvider.backendAvailable
                        ? 'No matches yet'
                        : 'Smart Matching is on its way',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      MatchProvider.backendAvailable
                          ? "We'll show your best matches here as soon as they're found."
                          : "We're putting the finishing touches on it. "
                              "Once it's live, your best-fit tasks and "
                              "collaborators will show up here automatically.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.secondaryText,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case MatchLoadStatus.loaded:
        final matches = provider.matches;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: matches.length,
          itemBuilder: (context, index) =>
              _buildMatchCard(context, matches[index], colors),
        );
    }
  }

  Widget _buildMatchCard(
      BuildContext context, MatchResult match, AppColors colors) {
    final isTask = match.type == MatchResultType.task;
    final scorePercent =
        match.score != null ? (match.score! * 100).clamp(0, 100).round() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.arahPurple.withOpacity(0.1),
            child: Icon(
              isTask ? Icons.assignment_outlined : Icons.person_outline,
              color: AppTheme.arahPurple,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.title.isNotEmpty ? match.title : 'Untitled',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                if (match.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    match.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.secondaryText,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (scorePercent != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.successBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$scorePercent%',
                style: TextStyle(
                  color: colors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

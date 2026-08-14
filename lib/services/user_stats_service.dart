import 'package:cloud_firestore/cloud_firestore.dart';

/// Result of a stats computation. All fields are real, derived values —
/// never hardcoded placeholders. A field is `null`/`0` when there isn't
/// enough underlying data yet, rather than showing a fake number.
class UserStats {
  final int tasksCompleted;
  final double avgRating;
  final int ratingCount;
  final int trustScore;
  final double? avgCompletionTimeMinutes;
  final double? responseRate;

  const UserStats({
    required this.tasksCompleted,
    required this.avgRating,
    required this.ratingCount,
    required this.trustScore,
    this.avgCompletionTimeMinutes,
    this.responseRate,
  });

  static const empty = UserStats(
    tasksCompleted: 0,
    avgRating: 0,
    ratingCount: 0,
    trustScore: 0,
  );
}

/// Computes the SYSTEM-GENERATED half of a user's profile.
///
/// This is intentionally isolated from [FirestoreService] and
/// [UserProvider]'s user-editable fields: nothing in this file is ever
/// exposed as an editable form field. It exists so that "Trust Score",
/// "Tasks Completed", etc. are always derived from real activity data
/// instead of being typed in anywhere.
///
/// Today this runs client-side against `orders` + the user's `ratings`
/// subcollection. If/when this needs to run at scale, this is the single
/// place to swap the implementation for a Cloud Function / scheduled
/// aggregation job — callers (UserProvider) don't need to change.
class UserStatsService {
  final FirebaseFirestore _db;

  UserStatsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<UserStats> computeStats(String uid) async {
    if (uid.isEmpty) return UserStats.empty;

    final results = await Future.wait([
      _completedOrdersFor(uid),
      _ratingsFor(uid),
    ]);
    final completedOrders = results[0] as List<QueryDocumentSnapshot>;
    final ratingDocs = results[1] as List<QueryDocumentSnapshot>;

    final tasksCompleted = completedOrders.length;

    double avgRating = 0;
    if (ratingDocs.isNotEmpty) {
      final sum = ratingDocs.fold<double>(
        0,
        (acc, doc) => acc + ((doc.data() as Map)['rating'] as num).toDouble(),
      );
      avgRating = sum / ratingDocs.length;
    }
    final ratingCount = ratingDocs.length;

    // Average completion time: only computable for orders that carry both
    // a createdAt and a completedAt timestamp. Older orders (completed
    // before this field existed) are simply excluded, not faked.
    final durations = <double>[];
    for (final doc in completedOrders) {
      final data = doc.data() as Map<String, dynamic>;
      final created = data['createdAt'];
      final completed = data['completedAt'];
      if (created is Timestamp && completed is Timestamp) {
        final minutes =
            completed.toDate().difference(created.toDate()).inMinutes;
        if (minutes >= 0) durations.add(minutes.toDouble());
      }
    }
    final avgCompletionTimeMinutes = durations.isEmpty
        ? null
        : durations.reduce((a, b) => a + b) / durations.length;

    // Response rate needs first-response timestamps on chats/orders, which
    // aren't tracked yet anywhere in the data model. Rather than invent a
    // number, this stays null (UI shows "Not enough data yet") until that
    // tracking exists. TODO(sprint3): stamp `firstResponseAt` when a seller
    // sends their first chat reply to a buyer's task inquiry, then compute
    // responseRate = replies-within-SLA / total-inquiries here.
    const double? responseRate = null;

    final trustScore = _computeTrustScore(
      avgRating: avgRating,
      ratingCount: ratingCount,
      tasksCompleted: tasksCompleted,
    );

    return UserStats(
      tasksCompleted: tasksCompleted,
      avgRating: avgRating,
      ratingCount: ratingCount,
      trustScore: trustScore,
      avgCompletionTimeMinutes: avgCompletionTimeMinutes,
      responseRate: responseRate,
    );
  }

  Future<List<QueryDocumentSnapshot>> _completedOrdersFor(String uid) async {
    final snap = await _db
        .collection('orders')
        .where('sellerId', isEqualTo: uid)
        .where('status', isEqualTo: 'Completed')
        .get();
    return snap.docs;
  }

  Future<List<QueryDocumentSnapshot>> _ratingsFor(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('ratings')
        .get();
    return snap.docs;
  }

  /// v1 trust score formula — deterministic function of real signals only:
  ///   - up to 70 points from average rating (rating / 5 * 70)
  ///   - up to 30 points from completed-task volume, capped at 30 tasks
  /// A brand-new user with no history scores 0, not some fake "starter"
  /// number. Revisit the weighting here as more signals become available
  /// (e.g. dispute rate, on-time rate) — this is the one place to change it.
  int _computeTrustScore({
    required double avgRating,
    required int ratingCount,
    required int tasksCompleted,
  }) {
    if (ratingCount == 0 && tasksCompleted == 0) return 0;
    final ratingComponent = (avgRating / 5.0) * 70;
    final volumeComponent = (tasksCompleted.clamp(0, 30) / 30) * 30;
    return (ratingComponent + volumeComponent).round().clamp(0, 100);
  }
}

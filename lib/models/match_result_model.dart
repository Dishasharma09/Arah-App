/// What kind of thing a match result points at.
enum MatchResultType { task, user }

/// A single Smart Matching result (a matched task or a matched user).
///
/// ── SPRINT 3 STATUS ──────────────────────────────────────────────────
/// Emmanuel has not yet provided the matching logic, the API endpoint,
/// or a documented response schema. This model is a forward-looking
/// placeholder so the UI layer has something typed to render — it does
/// NOT represent an agreed-upon backend contract.
///
/// `fromMap` reads a small set of common-sense keys defensively (falling
/// back across a couple of likely names) and always keeps the full raw
/// payload around in [raw] so nothing is lost once the real shape is
/// known. When Emmanuel ships the endpoint, this file should be updated
/// to match the real field names exactly and the defensive fallbacks
/// below should be removed.
///
/// See the Sprint 3 backend notes doc for exactly what's being requested
/// from the backend for this feature.
class MatchResult {
  final String id;
  final MatchResultType type;
  final String title;
  final String subtitle;

  /// 0.0–1.0 match strength, if the backend provides one. Used purely to
  /// order results (highest first) and to show an optional match badge —
  /// never invented on the frontend when absent.
  final double? score;

  /// The original payload, untouched, so no field is ever silently
  /// dropped while the schema is still unknown.
  final Map<String, dynamic> raw;

  const MatchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.score,
    this.raw = const {},
  });

  factory MatchResult.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? '').toString().toLowerCase();
    final rawScore = map['score'] ?? map['matchScore'];

    return MatchResult(
      id: id,
      type: typeStr == 'user' ? MatchResultType.user : MatchResultType.task,
      title: (map['title'] ?? map['name'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? map['description'] ?? '').toString(),
      score: rawScore is num ? rawScore.toDouble() : null,
      raw: map,
    );
  }
}

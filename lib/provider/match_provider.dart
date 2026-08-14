import 'package:flutter/material.dart';
import '../models/match_result_model.dart';

enum MatchLoadStatus { loading, loaded, empty, error }

/// Drives the Smart Matching screen.
///
/// ── SPRINT 3 STATUS ──────────────────────────────────────────────────
/// Emmanuel has not shipped the matching logic/API yet, so
/// [backendAvailable] is hard-coded to `false`. This provider
/// deliberately never invents match results — while the backend is
/// unavailable, [loadMatches] always resolves to an empty result set
/// (shown with a dedicated "coming soon" message in the UI, not a
/// misleading "no matches found").
///
/// The loading/loaded/empty/error state machine below, and the sorting
/// logic, are already fully built. Once the real endpoint exists:
///   1. Flip [backendAvailable] to `true`.
///   2. Replace the body of the `if (!backendAvailable)` branch in
///      [loadMatches] with the real fetch call.
///   3. Double check [MatchResult.fromMap] against the real response
///      schema (see match_result_model.dart).
class MatchProvider extends ChangeNotifier {
  static const bool backendAvailable = false;

  MatchLoadStatus _status = MatchLoadStatus.empty;
  MatchLoadStatus get status => _status;

  List<MatchResult> _matches = [];
  List<MatchResult> get matches => _matches;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadMatches(String uid) async {
    _status = MatchLoadStatus.loading;
    notifyListeners();

    if (!backendAvailable) {
      // Short delay so the loading state is genuinely visible/testable
      // instead of flashing for a single frame — not a simulation of a
      // real network call, just a UI-state pause.
      await Future.delayed(const Duration(milliseconds: 500));
      _matches = [];
      _status = MatchLoadStatus.empty;
      notifyListeners();
      return;
    }

    // --- Wire up here once Emmanuel ships the matching API ---
    // try {
    //   final results = await _service.fetchSmartMatches(uid);
    //   // Highest match strength first; results without a score sort last.
    //   results.sort((a, b) => (b.score ?? -1).compareTo(a.score ?? -1));
    //   _matches = results;
    //   _status =
    //       results.isEmpty ? MatchLoadStatus.empty : MatchLoadStatus.loaded;
    // } catch (e) {
    //   _errorMessage = e.toString();
    //   _status = MatchLoadStatus.error;
    // }
    // notifyListeners();
  }

  Future<void> retry(String uid) => loadMatches(uid);
}

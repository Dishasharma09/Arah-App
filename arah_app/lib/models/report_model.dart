import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String reason;
  final String description;
  final DateTime? createdAt; // nullable because we might get null from Firestore if not set
  final String status;
  final String? evidenceUrl; // optional, could be a URL to stored file
  final String? reviewedBy; // optional
  final DateTime? reviewedAt; // optional
  final String? resolutionNote; // optional

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    required this.description,
    this.createdAt,
    required this.status,
    this.evidenceUrl,
    this.reviewedBy,
    this.reviewedAt,
    this.resolutionNote,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    return ReportModel(
      id: id,
      reporterId: map['reporterId'] ?? '',
      reportedUserId: map['reportedUserId'] ?? '',
      reason: map['reason'] ?? '',
      description: map['description'] ?? '',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      status: map['status'] ?? 'Pending',
      evidenceUrl: map['evidenceUrl'],
      reviewedBy: map['reviewedBy'],
      reviewedAt: map['reviewedAt'] != null ? (map['reviewedAt'] as Timestamp).toDate() : null,
      resolutionNote: map['resolutionNote'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'description': description,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'status': status,
      'evidenceUrl': evidenceUrl,
    };
    // Add optional fields only if they have a value
    if (reviewedBy != null) {
      map['reviewedBy'] = reviewedBy;
    }
    if (reviewedAt != null) {
      map['reviewedAt'] = Timestamp.fromDate(reviewedAt!);
    }
    if (resolutionNote != null) {
      map['resolutionNote'] = resolutionNote;
    }
    return map;
  }
}
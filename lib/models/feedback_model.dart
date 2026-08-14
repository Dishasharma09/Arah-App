class FeedbackModel {
  final String userId;
  final String subject;
  final String message;
  final String appVersion;
  final DateTime timestamp;

  FeedbackModel({
    required this.userId,
    required this.subject,
    required this.message,
    required this.appVersion,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'subject': subject,
      'message': message,
      'appVersion': appVersion,
      'timestamp': timestamp,
    };
  }
}
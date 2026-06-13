class Interview {
  Interview({
    required this.id,
    required this.candidateId,
    required this.jobId,
    required this.ownerId,
    required this.scheduledAt,
    required this.durationMinutes,
    this.interviewerName,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.candidateName,
    this.candidateEmail,
    this.jobTitle,
  });

  final String id;
  final String candidateId;
  final String jobId;
  final String ownerId;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? interviewerName;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? candidateName;
  final String? candidateEmail;
  final String? jobTitle;

  factory Interview.fromJson(Map<String, dynamic> json) {
    final candidate = json['candidate'] as Map<String, dynamic>?;
    final job = json['job'] as Map<String, dynamic>?;

    return Interview(
      id: json['id'] as String,
      candidateId: json['candidateId'] as String,
      jobId: json['jobId'] as String,
      ownerId: json['ownerId'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      durationMinutes: json['durationMinutes'] as int? ?? 30,
      interviewerName: json['interviewerName'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'SCHEDULED',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      candidateName: candidate?['name'] as String?,
      candidateEmail: candidate?['email'] as String?,
      jobTitle: job?['title'] as String?,
    );
  }
}

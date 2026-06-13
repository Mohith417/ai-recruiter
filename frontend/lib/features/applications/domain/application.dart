class JobApplication {
  JobApplication({
    required this.id,
    required this.jobId,
    required this.applicantId,
    required this.stage,
    this.matchScore,
    this.applicantEmail,
    this.applicantName,
    this.jobTitle,
    this.companyName,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final String applicantId;
  final String stage;
  final int? matchScore;
  final String? applicantEmail;
  final String? applicantName;
  final String? jobTitle;
  final String? companyName;
  final DateTime createdAt;

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    final applicant = json['applicant'] as Map<String, dynamic>?;
    final job = json['job'] as Map<String, dynamic>?;
    return JobApplication(
      id: json['id'] as String,
      jobId: json['jobId'] as String,
      applicantId: json['applicantId'] as String,
      stage: json['stage'] as String? ?? 'APPLIED',
      matchScore: (json['matchScore'] as num?)?.toInt(),
      applicantEmail: applicant?['email'] as String?,
      applicantName: applicant?['name'] as String?,
      jobTitle: job?['title'] as String?,
      companyName: job?['location'] as String? ?? 'Various Companies',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

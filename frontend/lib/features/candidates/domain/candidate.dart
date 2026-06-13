class Candidate {
  Candidate({
    required this.id,
    this.name,
    this.email,
    this.resumeFileUrl,
    this.jobId,
    required this.status,
    required this.createdAt,
    this.score,
    this.cultureFitScore,
    this.cultureFitRationale,
    this.isApplication = false,
  });

  final String id;
  final String? name;
  final String? email;
  final String? resumeFileUrl;
  final String? jobId;
  final String status;
  final DateTime createdAt;
  final double? score;
  final int? cultureFitScore;
  final String? cultureFitRationale;
  final bool isApplication;

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      resumeFileUrl: json['resumeFileUrl'] as String?,
      jobId: json['jobId'] as String?,
      status: json['status'] as String? ?? 'PARSED',
      createdAt: DateTime.parse(json['createdAt'] as String),
      score: (json['score'] as num?)?.toDouble(),
      cultureFitScore: (json['cultureFitScore'] as num?)?.toInt(),
      cultureFitRationale: json['cultureFitRationale'] as String?,
      isApplication: json['isApplication'] as bool? ?? false,
    );
  }
}

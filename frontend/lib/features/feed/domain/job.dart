class Job {
  const Job({
    required this.id,
    required this.title,
    this.description,
    required this.location,
    required this.salaryMin,
    required this.salaryMax,
    required this.createdAt,
    this.matchScore,
  });

  final String id;
  final String title;
  final String? description;
  final String? location;
  final int? salaryMin;
  final int? salaryMax;
  final DateTime createdAt;
  final int? matchScore;

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      salaryMin: (json['salaryMin'] as num?)?.toInt(),
      salaryMax: (json['salaryMax'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      matchScore: (json['matchScore'] as num?)?.toInt(),
    );
  }
}


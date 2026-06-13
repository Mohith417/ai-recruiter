import 'package:dio/dio.dart';

import 'package:recruitment_app/features/feed/domain/job.dart';
import 'package:recruitment_app/shared/services/api_client.dart';

class JobsRepository {
  JobsRepository({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  Future<List<Job>> listJobs() async {
    final res = await _dio.get('/jobs');
    final data = (res.data as Map<String, dynamic>);
    final items = (data['jobs'] as List).cast<Map<String, dynamic>>();
    return items.map(Job.fromJson).toList();
  }

  Future<Job> getJob(String id) async {
    final res = await _dio.get('/jobs/$id');
    final data = (res.data as Map<String, dynamic>);
    final item = (data['job'] as Map<String, dynamic>);
    return Job.fromJson(item);
  }

  Future<Job> createJob({
    required String title,
    required String description,
    String? location,
    int? salaryMin,
    int? salaryMax,
  }) async {
    final res = await _dio.post(
      '/jobs',
      data: {
        'title': title,
        'description': description,
        if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
        if (salaryMin != null) 'salaryMin': salaryMin,
        if (salaryMax != null) 'salaryMax': salaryMax,
      },
    );
    final data = (res.data as Map<String, dynamic>);
    final job = (data['job'] as Map<String, dynamic>);
    return Job.fromJson(job);
  }
}

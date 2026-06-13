import 'package:dio/dio.dart';

import 'package:recruitment_app/features/applications/domain/application.dart';
import 'package:recruitment_app/shared/services/api_client.dart';

class ApplicationsRepository {
  ApplicationsRepository({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  Future<List<JobApplication>> listApplications({String? jobId}) async {
    final res = await _dio.get(
      '/applications',
      queryParameters: {
        if (jobId != null && jobId.trim().isNotEmpty) 'jobId': jobId.trim(),
      },
    );
    final data = (res.data as Map<String, dynamic>);
    final items = (data['applications'] as List).cast<Map<String, dynamic>>();
    return items.map(JobApplication.fromJson).toList();
  }

  Future<List<JobApplication>> listMyApplications() async {
    final res = await _dio.get('/applications/me');
    final data = (res.data as Map<String, dynamic>);
    final items = (data['applications'] as List).cast<Map<String, dynamic>>();
    return items.map(JobApplication.fromJson).toList();
  }

  Future<JobApplication> applyToJob({required String jobId}) async {
    final res = await _dio.post(
      '/applications',
      data: {'jobId': jobId.trim()},
    );
    final data = (res.data as Map<String, dynamic>);
    final item = (data['application'] as Map<String, dynamic>);
    return JobApplication.fromJson(item);
  }

  Future<JobApplication> updateStage({
    required String applicationId,
    required String stage,
  }) async {
    final res = await _dio.patch(
      '/applications/$applicationId/stage',
      data: {'stage': stage.trim().toUpperCase()},
    );
    final data = (res.data as Map<String, dynamic>);
    final item = (data['application'] as Map<String, dynamic>);
    return JobApplication.fromJson(item);
  }
}

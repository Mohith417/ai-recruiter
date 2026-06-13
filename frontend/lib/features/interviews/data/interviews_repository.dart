import 'package:dio/dio.dart';
import 'package:recruitment_app/features/interviews/domain/interview.dart';
import 'package:recruitment_app/shared/services/api_client.dart';

class InterviewsRepository {
  InterviewsRepository({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  Future<List<Interview>> fetchInterviews({String? candidateId, String? jobId}) async {
    final res = await _dio.get(
      '/interviews',
      queryParameters: {
        if (candidateId != null && candidateId.trim().isNotEmpty) 'candidateId': candidateId.trim(),
        if (jobId != null && jobId.trim().isNotEmpty) 'jobId': jobId.trim(),
      },
    );
    final data = res.data as Map<String, dynamic>;
    final items = (data['interviews'] as List).cast<Map<String, dynamic>>();
    return items.map(Interview.fromJson).toList();
  }

  Future<Interview> createInterview({
    required String candidateId,
    required String jobId,
    required DateTime scheduledAt,
    int durationMinutes = 30,
    String? interviewerName,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'candidateId': candidateId,
      'jobId': jobId,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      'interviewerName': interviewerName,
      'notes': notes,
    }..removeWhere((_, v) => v == null);

    final res = await _dio.post('/interviews', data: payload);
    final data = res.data as Map<String, dynamic>;
    final item = data['interview'] as Map<String, dynamic>;
    return Interview.fromJson(item);
  }

  Future<Interview> updateInterview({
    required String id,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? interviewerName,
    String? notes,
    String? status,
  }) async {
    final payload = <String, dynamic>{
      if (scheduledAt != null) 'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (interviewerName != null) 'interviewerName': interviewerName,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
    };

    final res = await _dio.patch('/interviews/$id', data: payload);
    final data = res.data as Map<String, dynamic>;
    final item = data['interview'] as Map<String, dynamic>;
    return Interview.fromJson(item);
  }

  Future<void> deleteInterview(String id) async {
    await _dio.delete('/interviews/$id');
  }
}

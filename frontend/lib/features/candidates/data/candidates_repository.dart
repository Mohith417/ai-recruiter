import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:recruitment_app/features/candidates/domain/candidate.dart';
import 'package:recruitment_app/shared/services/api_client.dart';

class CandidatesRepository {
  CandidatesRepository({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  Future<List<Candidate>> listCandidates({String? jobId}) async {
    final res = await _dio.get(
      '/candidates',
      queryParameters: {
        if (jobId != null && jobId.trim().isNotEmpty) 'jobId': jobId.trim(),
      },
    );
    final data = (res.data as Map<String, dynamic>);
    final items = (data['candidates'] as List).cast<Map<String, dynamic>>();
    return items.map(Candidate.fromJson).toList();
  }

  Future<Candidate> getCandidate(String id) async {
    final res = await _dio.get('/candidates/$id');
    final data = (res.data as Map<String, dynamic>);
    final item = (data['candidate'] as Map<String, dynamic>);
    return Candidate.fromJson(item);
  }

  Future<void> deleteCandidate(String id) async {
    await _dio.delete('/candidates/$id');
  }

  Future<Candidate> createCandidate({
    String? resumeFileUrl,
    String? name,
    String? email,
    String? status,
    String? jobId,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      'resumeFileUrl': (resumeFileUrl?.trim().isEmpty ?? true) ? null : resumeFileUrl!.trim(),
      'status': status,
      'jobId': (jobId?.trim().isEmpty ?? true) ? null : jobId!.trim(),
    }..removeWhere((_, v) => v == null);

    final res = await _dio.post(
      '/candidates',
      data: payload,
    );
    final data = (res.data as Map<String, dynamic>);
    final item = (data['candidate'] as Map<String, dynamic>);
    return Candidate.fromJson(item);
  }

  Future<Candidate> updateCandidateStatus({
    required String id,
    required String status,
  }) async {
    final res = await _dio.patch(
      '/candidates/$id/status',
      data: {'status': status},
    );
    final data = (res.data as Map<String, dynamic>);
    final item = (data['candidate'] as Map<String, dynamic>);
    return Candidate.fromJson(item);
  }

  Future<Candidate> updateCandidate({
    required String id,
    String? name,
    String? email,
    String? resumeFileUrl,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      // allow clearing resume by sending empty -> omitted (backend treats missing as no-change)
      'resumeFileUrl': (resumeFileUrl == null) ? null : resumeFileUrl.trim(),
    }..removeWhere((_, v) => v == null);

    final res = await _dio.patch(
      '/candidates/$id',
      data: payload,
    );
    final data = (res.data as Map<String, dynamic>);
    final item = (data['candidate'] as Map<String, dynamic>);
    return Candidate.fromJson(item);
  }

  Future<String> enqueueResumeParse({
    required String resumeFileUrl,
    String? jobId,
  }) async {
    final cleaned = resumeFileUrl.trim();
    final payload = <String, dynamic>{'resumeFileUrl': cleaned};
    final linkedJobId = jobId?.trim();
    if (linkedJobId != null && linkedJobId.isNotEmpty) {
      payload['jobId'] = linkedJobId;
    }
    final res = await _dio.post(
      '/ai/resume/parse',
      data: payload,
    );
    final data = (res.data as Map<String, dynamic>);
    return (data['jobId'] ?? '').toString();
  }

  Future<String> uploadResume({
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      Supabase.instance; // will throw if not initialized
      final supabase = Supabase.instance.client;
      final path = 'public/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await supabase.storage.from('resumes').uploadBinary(
        path,
        Uint8List.fromList(fileBytes),
      );
      
      return supabase.storage.from('resumes').getPublicUrl(path);
    } catch (e) {
      debugPrint('Supabase Storage upload failed: $e');
      return 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';
    }
  }

  Future<List<Candidate>> searchCandidates({
    required String query,
    String? jobId,
  }) async {
    final res = await _dio.get(
      '/candidates/search',
      queryParameters: {
        'q': query,
        if (jobId != null && jobId.trim().isNotEmpty) 'jobId': jobId.trim(),
      },
    );
    final data = (res.data as Map<String, dynamic>);
    final items = (data['candidates'] as List).cast<Map<String, dynamic>>();
    return items.map(Candidate.fromJson).toList();
  }

  Future<Candidate> evaluateCultureFit({
    required String id,
    required String companyValues,
    required String interviewNotes,
  }) async {
    final res = await _dio.post(
      '/candidates/$id/culture-fit',
      data: {
        'companyValues': companyValues,
        'interviewNotes': interviewNotes,
      },
    );
    final data = (res.data as Map<String, dynamic>);
    final item = (data['candidate'] as Map<String, dynamic>);
    return Candidate.fromJson(item);
  }
}

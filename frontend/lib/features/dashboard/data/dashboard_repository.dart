import 'package:dio/dio.dart';
import 'package:recruitment_app/features/dashboard/domain/audit_log.dart';
import 'package:recruitment_app/shared/services/api_client.dart';

class DashboardStats {
  DashboardStats({
    required this.activeCandidates,
    required this.interviews,
    required this.hired,
    required this.jobs,
  });

  final int activeCandidates;
  final int interviews;
  final int hired;
  final int jobs;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      activeCandidates: json['activeCandidates'] as int? ?? 0,
      interviews: json['interviews'] as int? ?? 0,
      hired: json['hired'] as int? ?? 0,
      jobs: json['jobs'] as int? ?? 0,
    );
  }
}

class DashboardRepository {
  DashboardRepository({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  Future<List<AuditLog>> getAuditLogs() async {
    final res = await _dio.get('/audit-logs');
    final data = res.data as Map<String, dynamic>;
    final items = (data['auditLogs'] as List).cast<Map<String, dynamic>>();
    return items.map(AuditLog.fromJson).toList();
  }

  Future<void> deleteAuditLog(String id) async {
    await _dio.delete('/audit-logs/$id');
  }

  Future<void> deleteAllAuditLogs() async {
    await _dio.delete('/audit-logs');
  }

  Future<void> restoreAuditLogs(List<AuditLog> logs) async {
    await _dio.post('/audit-logs/restore', data: {
      'logs': logs.map((l) => l.toJson()).toList(),
    });
  }

  Future<DashboardStats> getStats({String? jobId, DateTime? startDate, DateTime? endDate}) async {
    final res = await _dio.get(
      '/dashboard/stats',
      queryParameters: {
        if (jobId != null) 'jobId': jobId,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
    final data = res.data as Map<String, dynamic>;
    return DashboardStats.fromJson(data['stats'] as Map<String, dynamic>);
  }

  Future<Map<String, int>> getFunnel({String? jobId, DateTime? startDate, DateTime? endDate}) async {
    final res = await _dio.get(
      '/dashboard/funnel',
      queryParameters: {
        if (jobId != null) 'jobId': jobId,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
    final data = res.data as Map<String, dynamic>;
    final funnel = data['funnel'] as Map<String, dynamic>;
    return funnel.map((k, v) => MapEntry(k, v as int));
  }

  Future<List<ActivityTimelineEntry>> getActivityTimeline({String? jobId, DateTime? startDate, DateTime? endDate}) async {
    final res = await _dio.get(
      '/dashboard/activity-timeline',
      queryParameters: {
        if (jobId != null) 'jobId': jobId,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
    final data = res.data as Map<String, dynamic>;
    final items = (data['timeline'] as List).cast<Map<String, dynamic>>();
    return items.map(ActivityTimelineEntry.fromJson).toList();
  }
}

class ActivityTimelineEntry {
  ActivityTimelineEntry({
    required this.date,
    required this.count,
  });

  final String date;
  final int count;

  factory ActivityTimelineEntry.fromJson(Map<String, dynamic> json) {
    return ActivityTimelineEntry(
      date: json['date'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recruitment_app/features/dashboard/data/dashboard_repository.dart';
import 'package:recruitment_app/features/dashboard/domain/audit_log.dart';

class DashboardFilters {
  const DashboardFilters({this.jobId, this.startDate, this.endDate});
  
  final String? jobId;
  final DateTime? startDate;
  final DateTime? endDate;

  DashboardFilters copyWith({
    String? Function()? jobId,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
  }) {
    return DashboardFilters(
      jobId: jobId != null ? jobId() : this.jobId,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
    );
  }
}

class DashboardFiltersNotifier extends StateNotifier<DashboardFilters> {
  DashboardFiltersNotifier() : super(const DashboardFilters());

  void setJobId(String? jobId) {
    state = state.copyWith(jobId: () => jobId);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(
      startDate: () => start,
      endDate: () => end,
    );
  }

  void reset() {
    state = const DashboardFilters();
  }
}

final dashboardFiltersProvider = StateNotifierProvider<DashboardFiltersNotifier, DashboardFilters>((ref) {
  return DashboardFiltersNotifier();
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

final dashboardActivityProvider = FutureProvider<List<AuditLog>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getAuditLogs();
});

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final filters = ref.watch(dashboardFiltersProvider);
  return repo.getStats(
    jobId: filters.jobId,
    startDate: filters.startDate,
    endDate: filters.endDate,
  );
});

final dashboardFunnelProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final filters = ref.watch(dashboardFiltersProvider);
  return repo.getFunnel(
    jobId: filters.jobId,
    startDate: filters.startDate,
    endDate: filters.endDate,
  );
});

final dashboardTimelineProvider = FutureProvider<List<ActivityTimelineEntry>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final filters = ref.watch(dashboardFiltersProvider);
  return repo.getActivityTimeline(
    jobId: filters.jobId,
    startDate: filters.startDate,
    endDate: filters.endDate,
  );
});

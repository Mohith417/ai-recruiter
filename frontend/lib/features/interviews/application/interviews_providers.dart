import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recruitment_app/features/interviews/data/interviews_repository.dart';
import 'package:recruitment_app/features/interviews/domain/interview.dart';

final interviewsRepositoryProvider = Provider<InterviewsRepository>((ref) {
  return InterviewsRepository();
});

final interviewsListProvider = FutureProvider.family<List<Interview>, ({String? candidateId, String? jobId})>((ref, arg) async {
  final repo = ref.watch(interviewsRepositoryProvider);
  return repo.fetchInterviews(candidateId: arg.candidateId, jobId: arg.jobId);
});

final allInterviewsProvider = FutureProvider<List<Interview>>((ref) async {
  final repo = ref.watch(interviewsRepositoryProvider);
  return repo.fetchInterviews();
});

class InterviewsNotifier extends StateNotifier<AsyncValue<void>> {
  InterviewsNotifier({required this.repository, required this.ref})
      : super(const AsyncData(null));

  final InterviewsRepository repository;
  final Ref ref;

  Future<bool> createInterview({
    required String candidateId,
    required String jobId,
    required DateTime scheduledAt,
    int durationMinutes = 30,
    String? interviewerName,
    String? notes,
  }) async {
    state = const AsyncLoading();
    try {
      await repository.createInterview(
        candidateId: candidateId,
        jobId: jobId,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        interviewerName: interviewerName,
        notes: notes,
      );
      state = const AsyncData(null);
      ref.invalidate(allInterviewsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> updateInterview({
    required String id,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? interviewerName,
    String? notes,
    String? status,
  }) async {
    state = const AsyncLoading();
    try {
      await repository.updateInterview(
        id: id,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        interviewerName: interviewerName,
        notes: notes,
        status: status,
      );
      state = const AsyncData(null);
      ref.invalidate(allInterviewsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> deleteInterview(String id) async {
    state = const AsyncLoading();
    try {
      await repository.deleteInterview(id);
      state = const AsyncData(null);
      ref.invalidate(allInterviewsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final interviewsNotifierProvider = StateNotifierProvider<InterviewsNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(interviewsRepositoryProvider);
  return InterviewsNotifier(repository: repo, ref: ref);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recruitment_app/features/feed/data/jobs_repository.dart';
import 'package:recruitment_app/features/feed/domain/job.dart';

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository();
});

final jobsFeedProvider = FutureProvider<List<Job>>((ref) async {
  final repo = ref.watch(jobsRepositoryProvider);
  return repo.listJobs();
});

final jobByIdProvider = FutureProvider.family<Job, String>((ref, id) async {
  final repo = ref.watch(jobsRepositoryProvider);
  return repo.getJob(id);
});

/// Local-only (Phase 1) state: saved/skimmed jobs.
///
/// Later we can persist these to backend (e.g., /jobs/:id/save, /jobs/:id/skip).
final savedJobIdsProvider = StateProvider<Set<String>>((ref) => <String>{});
final skippedJobIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

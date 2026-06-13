import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recruitment_app/features/applications/data/applications_repository.dart';
import 'package:recruitment_app/features/applications/domain/application.dart';

final applicationsRepositoryProvider = Provider<ApplicationsRepository>((ref) {
  return ApplicationsRepository();
});

final applicationsByJobProvider = FutureProvider.family<List<JobApplication>, String>((ref, jobId) async {
  final repo = ref.watch(applicationsRepositoryProvider);
  return repo.listApplications(jobId: jobId);
});

final myApplicationsProvider = FutureProvider<List<JobApplication>>((ref) async {
  final repo = ref.watch(applicationsRepositoryProvider);
  return repo.listMyApplications();
});

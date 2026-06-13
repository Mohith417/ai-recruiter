import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recruitment_app/features/candidates/data/candidates_repository.dart';
import 'package:recruitment_app/features/candidates/domain/candidate.dart';

final candidatesRepositoryProvider = Provider<CandidatesRepository>((ref) {
  return CandidatesRepository();
});

final candidatesFeedProvider = FutureProvider<List<Candidate>>((ref) async {
  final repo = ref.watch(candidatesRepositoryProvider);
  return repo.listCandidates();
});

final candidatesByJobProvider = FutureProvider.family<List<Candidate>, String?>((ref, jobId) async {
  final repo = ref.watch(candidatesRepositoryProvider);
  return repo.listCandidates(jobId: jobId);
});

final candidateByIdProvider = FutureProvider.family<Candidate, String>((ref, id) async {
  final repo = ref.watch(candidatesRepositoryProvider);
  return repo.getCandidate(id);
});

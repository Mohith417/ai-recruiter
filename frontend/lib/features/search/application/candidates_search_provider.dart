import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recruitment_app/features/candidates/application/candidates_providers.dart';
import 'package:recruitment_app/features/candidates/domain/candidate.dart';

final candidatesSearchQueryProvider = StateProvider<String>((ref) => '');

final candidatesSearchResultProvider = FutureProvider<List<Candidate>>((ref) async {
  final query = ref.watch(candidatesSearchQueryProvider).trim();
  if (query.isEmpty) {
    return const [];
  }
  final repo = ref.watch(candidatesRepositoryProvider);
  return repo.searchCandidates(query: query);
});

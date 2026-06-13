import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recruitment_app/features/search/application/candidates_search_provider.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(candidatesSearchQueryProvider);
    _searchCtrl = TextEditingController(text: initialQuery);
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _submitSearch(String val) {
    ref.read(candidatesSearchQueryProvider.notifier).state = val.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final searchResult = ref.watch(candidatesSearchResultProvider);
    final query = ref.watch(candidatesSearchQueryProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Smart Search', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search "frontend dev", "UI engineer"...',
                        hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                        border: InputBorder.none,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                      onSubmitted: _submitSearch,
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      tooltip: 'Clear',
                      onPressed: () {
                        _searchCtrl.clear();
                        _submitSearch('');
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_forward_rounded, color: cs.primary),
                      tooltip: 'Search',
                      onPressed: () {
                        _submitSearch(_searchCtrl.text);
                      },
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.search_rounded, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                    ),
                ],
              ),
            ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),
            const SizedBox(height: 14),
            if (query.isEmpty) ...[
              Text('Suggested', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Chip('Remote React', onTap: () {
                    _searchCtrl.text = 'Remote React';
                    _submitSearch('Remote React');
                  }),
                  _Chip('AI Engineer', onTap: () {
                    _searchCtrl.text = 'AI Engineer';
                    _submitSearch('AI Engineer');
                  }),
                  _Chip('Product Designer', onTap: () {
                    _searchCtrl.text = 'Product Designer';
                    _submitSearch('Product Designer');
                  }),
                  _Chip('Java Developer', onTap: () {
                    _searchCtrl.text = 'Java Developer';
                    _submitSearch('Java Developer');
                  }),
                ],
              ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),
            ],
            const SizedBox(height: 18),
            Expanded(
              child: query.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, size: 64, color: cs.primary.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          Text(
                            'Enter search keywords to find candidates.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : searchResult.when(
                      data: (candidates) {
                        if (candidates.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.sentiment_dissatisfied_rounded, size: 64, color: cs.primary.withValues(alpha: 0.2)),
                                const SizedBox(height: 12),
                                Text(
                                  'No matching candidates found.',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: candidates.length,
                          itemBuilder: (context, index) {
                            final candidate = candidates[index];
                            final scorePct = ((candidate.score ?? 0.0) * 100).toStringAsFixed(0);
                            final color = (candidate.score ?? 0.0) > 0.75
                                ? Colors.green
                                : (candidate.score ?? 0.0) > 0.4
                                    ? Colors.amber
                                    : Colors.orange;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => context.push('/candidates/${candidate.id}'),
                                child: GlassCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 48,
                                      width: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: cs.primary.withValues(alpha: 0.1),
                                      ),
                                      child: Center(
                                        child: Text(
                                          candidate.name?.isNotEmpty == true
                                              ? candidate.name!.substring(0, 1).toUpperCase()
                                              : 'C',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            candidate.name ?? 'Unnamed Candidate',
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            candidate.email ?? 'No email',
                                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  color: cs.surfaceContainerHighest,
                                                ),
                                                child: Text(
                                                  candidate.status,
                                                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                                                ),
                                              ),
                                              if (candidate.resumeFileUrl != null) ...[
                                                const SizedBox(width: 8),
                                                Icon(Icons.link_rounded, size: 14, color: cs.primary),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$scorePct%',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: color,
                                          ),
                                        ),
                                        Text(
                                          'Match',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ),
                            ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.05, curve: Curves.easeOutCubic);
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (err, stack) => Center(
                        child: Text('Search failed: $err'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
      ),
    );
  }
}

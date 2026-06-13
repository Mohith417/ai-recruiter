import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';

import 'package:recruitment_app/features/feed/application/jobs_providers.dart';
import 'package:recruitment_app/features/feed/domain/job.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';
import 'package:recruitment_app/shared/widgets/shimmer_block.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jobsAsync = ref.watch(jobsFeedProvider);
    final savedIds = ref.watch(savedJobIdsProvider);
    final skippedIds = ref.watch(skippedJobIdsProvider);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> refresh() async {
      // `invalidate` marks the provider as stale so it re-fetches on next read.
      ref.invalidate(jobsFeedProvider);
    }

    return RefreshIndicator.adaptive(
      onRefresh: refresh,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Job feed'),
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Reset hidden',
                onPressed: () {
                  ref.read(skippedJobIdsProvider.notifier).state = <String>{};
                  // Force a rebuild + refetch (helps on web where list state can feel "stuck").
                  ref.invalidate(jobsFeedProvider);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Hidden jobs restored')),
                  );
                },
                icon: const Icon(Icons.restore_rounded),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
            sliver: jobsAsync.when(
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _JobCardSkeleton(index: i),
                  ),
                  childCount: 8,
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Failed to load jobs.\nMake sure backend is running on http://localhost:4000',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (jobs) {
                final visibleJobs = jobs.where((j) => !skippedIds.contains(j.id)).toList();

                if (visibleJobs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.inbox_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No jobs in your feed right now.\nPull to refresh.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final job = visibleJobs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: ValueKey('job-${job.id}'),
                          direction: DismissDirection.horizontal,
                          dragStartBehavior: DragStartBehavior.down,
                          dismissThresholds: const {
                            // Make swipe actions easy on web/desktop (shorter drag distance).
                            DismissDirection.startToEnd: 0.18, // Save
                            DismissDirection.endToStart: 0.30, // Skip
                          },
                          background: _SwipeBackground(
                            alignment: Alignment.centerLeft,
                            color: Colors.green,
                            icon: Icons.bookmark_add_rounded,
                            label: 'Save',
                          ),
                          secondaryBackground: _SwipeBackground(
                            alignment: Alignment.centerRight,
                            color: Colors.red,
                            icon: Icons.close_rounded,
                            label: 'Skip',
                          ),
                          confirmDismiss: (dir) async {
                            if (dir == DismissDirection.startToEnd) {
                              // Save (but keep card in feed).
                              ref.read(savedJobIdsProvider.notifier).state = {
                                ...ref.read(savedJobIdsProvider),
                                job.id,
                              };
                              messenger.clearSnackBars();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Saved: ${job.title}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              return false;
                            }
                            // Skip (remove from feed).
                            return true;
                          },
                          onDismissed: (dir) {
                            ref.read(skippedJobIdsProvider.notifier).state = {
                              ...ref.read(skippedJobIdsProvider),
                              job.id,
                            };
                            messenger.clearSnackBars();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Skipped: ${job.title}'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () {
                                    final current = ref.read(skippedJobIdsProvider);
                                    final next = {...current}..remove(job.id);
                                    ref.read(skippedJobIdsProvider.notifier).state = next;
                                  },
                                ),
                              ),
                            );
                          },
                          child: _JobCard(job: job, index: i, isSaved: savedIds.contains(job.id)),
                        ),
                      );
                    },
                    childCount: visibleJobs.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.index, required this.isSaved});

  final Job job;
  final int index;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String salaryText() {
      if (job.salaryMin == null && job.salaryMax == null) return 'Salary not disclosed';
      final fmt = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0);
      final min = job.salaryMin != null ? fmt.format(job.salaryMin) : null;
      final max = job.salaryMax != null ? fmt.format(job.salaryMax) : null;
      if (min != null && max != null) return '$min – $max';
      return min ?? max ?? 'Salary not disclosed';
    }

    // Dynamic match score from backend (with fallback to deterministic placeholder)
    final match = job.matchScore ?? (68 + (job.id.codeUnitAt(0) % 24));

    return GlassCard(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening job...')),
        );
        context.push('/jobs/${job.id}');
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
            ),
            child: Icon(Icons.apartment_rounded, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  job.location ?? 'Location: —',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  salaryText(),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: match >= 80 ? Colors.green.withValues(alpha: 0.14) : Colors.orange.withValues(alpha: 0.14),
                ),
                child: Text(
                  '$match%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: match >= 80 ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
              ),
              if (isSaved) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: cs.primary.withValues(alpha: 0.14),
                  ),
                  child: Text(
                    'Saved',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (40 * index).ms).slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _JobCardSkeleton extends StatelessWidget {
  const _JobCardSkeleton({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBlock(height: 44, width: 44, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBlock(height: 12, width: double.infinity, radius: 8),
                SizedBox(height: 10),
                ShimmerBlock(height: 10, width: 180, radius: 8),
                SizedBox(height: 10),
                ShimmerBlock(height: 10, width: 220, radius: 8),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const ShimmerBlock(height: 24, width: 46, radius: 12),
        ],
      ),
    ).animate().fadeIn(delay: (40 * index).ms).slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:recruitment_app/core/constants/app_colors.dart';
import 'package:recruitment_app/features/interviews/application/interviews_providers.dart';
import 'package:recruitment_app/features/interviews/domain/interview.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';
import 'package:recruitment_app/shared/widgets/shimmer_block.dart';

class InterviewsListPage extends ConsumerStatefulWidget {
  const InterviewsListPage({super.key});

  @override
  ConsumerState<InterviewsListPage> createState() => _InterviewsListPageState();
}

class _InterviewsListPageState extends ConsumerState<InterviewsListPage> {
  int _activeTab = 0; // 0: Upcoming, 1: Past / All

  Future<void> _refresh() async {
    ref.invalidate(allInterviewsProvider);
  }

  Future<void> _cancelInterview(Interview interview) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Interview'),
        content: Text('Are you sure you want to cancel the interview for ${interview.candidateName ?? "this candidate"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel Interview'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final notifier = ref.read(interviewsNotifierProvider.notifier);
    final success = await notifier.deleteInterview(interview.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interview cancelled successfully')),
      );
    } else {
      final error = ref.read(interviewsNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: $error')),
      );
    }
  }

  Future<void> _markCompleted(Interview interview) async {
    final notifier = ref.read(interviewsNotifierProvider.notifier);
    final success = await notifier.updateInterview(
      id: interview.id,
      status: 'COMPLETED',
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interview marked as completed')),
      );
    } else {
      final error = ref.read(interviewsNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interviewsAsync = ref.watch(allInterviewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interviews'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/interviews/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Schedule'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        child: Column(
          children: [
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Upcoming',
                    isActive: _activeTab == 0,
                    onTap: () => setState(() => _activeTab = 0),
                  ),
                  const SizedBox(width: 12),
                  _TabButton(
                    label: 'All / Past',
                    isActive: _activeTab == 1,
                    onTap: () => setState(() => _activeTab = 1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: interviewsAsync.when(
                data: (interviews) {
                  final now = DateTime.now();
                  final filtered = interviews.where((i) {
                    if (_activeTab == 0) {
                      return i.scheduledAt.isAfter(now) && i.status == 'SCHEDULED';
                    }
                    return true; // Return all for the second tab
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _activeTab == 0 ? 'No upcoming interviews' : 'No interviews scheduled yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_activeTab == 0)
                              FilledButton.icon(
                                onPressed: () => context.push('/interviews/new'),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Schedule one now'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final interview = filtered[index];
                      return _InterviewCard(
                        interview: interview,
                        onCancel: () => _cancelInterview(interview),
                        onComplete: () => _markCompleted(interview),
                      ).animate().fadeIn(delay: (40 * index).ms).slideY(begin: 0.05, curve: Curves.easeOutCubic);
                    },
                  );
                },
                loading: () => const _InterviewsSkeleton(),
                error: (err, _) => Center(
                  child: Text('Failed to load interviews: $err'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isActive ? cs.primary : cs.surfaceContainerHighest.withValues(alpha: 0.12),
            border: Border.all(
              color: isActive ? cs.primary : cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _InterviewCard extends StatelessWidget {
  const _InterviewCard({
    required this.interview,
    required this.onCancel,
    required this.onComplete,
  });

  final Interview interview;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dateStr = DateFormat('EEEE, MMMM dd').format(interview.scheduledAt);
    final timeStr = DateFormat('hh:mm a').format(interview.scheduledAt);
    final endTime = interview.scheduledAt.add(Duration(minutes: interview.durationMinutes));
    final endTimeStr = DateFormat('hh:mm a').format(endTime);

    Color statusColor = AppColors.indigo;
    if (interview.status == 'COMPLETED') {
      statusColor = Colors.green;
    } else if (interview.status == 'CANCELLED') {
      statusColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    interview.candidateName ?? interview.candidateEmail ?? 'Unnamed Candidate',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: statusColor.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    interview.status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              interview.jobTitle ?? 'Linked Job Position',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  '$dateStr at $timeStr - $endTimeStr',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (interview.interviewerName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_pin_rounded, size: 18, color: cs.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Interviewer: ${interview.interviewerName}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (interview.notes != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      interview.notes!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (interview.status == 'SCHEDULED') ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Complete'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InterviewsSkeleton extends StatelessWidget {
  const _InterviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBlock(height: 18, width: 140, radius: 8),
                    ShimmerBlock(height: 22, width: 80, radius: 8),
                  ],
                ),
                SizedBox(height: 8),
                ShimmerBlock(height: 14, width: 200, radius: 8),
                Divider(height: 24),
                ShimmerBlock(height: 16, width: 180, radius: 8),
                SizedBox(height: 8),
                ShimmerBlock(height: 16, width: 150, radius: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

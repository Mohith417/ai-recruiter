import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:recruitment_app/core/constants/app_colors.dart';
import 'package:recruitment_app/features/dashboard/application/dashboard_providers.dart';
import 'package:recruitment_app/features/candidates/application/candidates_providers.dart';
import 'package:recruitment_app/features/feed/application/jobs_providers.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';
import 'package:recruitment_app/shared/widgets/shimmer_block.dart';
import 'package:recruitment_app/features/shell/presentation/shell_scaffold.dart';
import 'package:recruitment_app/features/dashboard/domain/audit_log.dart';
import 'package:recruitment_app/features/auth/application/auth_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authNotifierProvider);

    final rawRole = auth.dbUser?.role?.toString().toUpperCase().trim();
    final isCandidate = rawRole == 'JOB_SEEKER';
    final isRecruiter = (rawRole == 'RECRUITER' ||
        rawRole == 'ADMIN' ||
        rawRole == 'HR_MANAGER' ||
        rawRole == 'COMPANY') && !isCandidate;

    if (!isRecruiter) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Unauthorized access.',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('This dashboard is for recruiters only.'),
            ],
          ),
        ),
      );
    }

    final avatarUrl = auth.dbUser?.avatarUrl;
    final displayName = auth.dbUser?.name ?? 'Recruiter';
    final initials = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';

    Future<void> refresh() async {
      ref.invalidate(dashboardActivityProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(dashboardFunnelProvider);
      ref.invalidate(dashboardTimelineProvider);
    }

    return RefreshIndicator.adaptive(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            title: Text('Good evening', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              const NotificationBell(),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Tooltip(
                  message: 'Profile Settings',
                  child: InkWell(
                    onTap: () => context.push('/settings'),
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: avatarUrl == null || avatarUrl.isEmpty
                          ? AppColors.indigo
                          : Colors.transparent,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed(
                [
                  _HeroBanner().animate().fadeIn(duration: 220.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
                  const SizedBox(height: 14),
                  _MetricsStrip().animate().fadeIn(delay: 80.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
                  const SizedBox(height: 14),
                  const _DashboardFiltersRow().animate().fadeIn(delay: 100.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
                  const SizedBox(height: 14),
                  Text('Quick actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _QuickActionsGrid().animate().fadeIn(delay: 120.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
                  const SizedBox(height: 18),
                  Text('Hiring funnel', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _FunnelCard().animate().fadeIn(delay: 140.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
                  const SizedBox(height: 18),
                  Text('Activity trend', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _TimelineCard().animate().fadeIn(delay: 160.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent activity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const _DeleteAllActivitiesButton(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const _RecentActivityList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your hiring hub', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Intelligent shortlisting, interviews, and automated pipeline management — all in one place.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.push('/search'),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Run AI shortlist'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppColors.indigo, AppColors.cyan]),
              boxShadow: [BoxShadow(color: AppColors.indigo.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: const Icon(Icons.work_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _MetricsStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return statsAsync.when(
      data: (stats) => Row(
        children: [
          Expanded(child: _MetricPill(label: 'Candidates', value: '${stats.activeCandidates}')),
          const SizedBox(width: 10),
          Expanded(child: _MetricPill(label: 'Interviews', value: '${stats.interviews}')),
          const SizedBox(width: 10),
          Expanded(child: _MetricPill(label: 'Jobs', value: '${stats.jobs}')),
        ],
      ),
      loading: () => Row(
        children: const [
          Expanded(child: _MetricPill(label: 'Candidates', value: '—')),
          SizedBox(width: 10),
          Expanded(child: _MetricPill(label: 'Interviews', value: '—')),
          SizedBox(width: 10),
          Expanded(child: _MetricPill(label: 'Jobs', value: '—')),
        ],
      ),
      error: (_, __) => Row(
        children: const [
          Expanded(child: _MetricPill(label: 'Candidates', value: '?')),
          SizedBox(width: 10),
          Expanded(child: _MetricPill(label: 'Interviews', value: '?')),
          SizedBox(width: 10),
          Expanded(child: _MetricPill(label: 'Jobs', value: '?')),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = const [
      _QuickAction('Post a job', Icons.add_rounded),
      _QuickAction('Bulk upload', Icons.upload_rounded),
      _QuickAction('Schedule', Icons.calendar_month_rounded),
      _QuickAction('Messages', Icons.chat_bubble_rounded),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.7,
      ),
      itemBuilder: (context, i) {
        final a = actions[i];
        return GlassCard(
          onTap: () {
            if (i == 0) {
              context.push('/jobs/new');
            } else if (i == 1) {
              _openResumeParseDialog(context, ref);
            } else if (i == 2) {
              context.push('/interviews/new');
            } else if (i == 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messages inbox coming soon!')),
              );
            }
          },
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.indigo.withValues(alpha: 0.12),
                ),
                child: Icon(a.icon, color: AppColors.indigo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(a.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (40 * i).ms).slideX(begin: 0.03, curve: Curves.easeOutCubic);
      },
    );
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _RecentActivityList extends ConsumerWidget {
  const _RecentActivityList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activityAsync = ref.watch(dashboardActivityProvider);

    return activityAsync.when(
      loading: () => const _ActivitySkeleton(),
      error: (err, _) => GlassCard(
        padding: const EdgeInsets.all(14),
        child: Text('Failed to load activity logs.\n$err', style: theme.textTheme.bodyMedium),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.history_toggle_off_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No recruiter activity yet.\nStart by uploading a resume in the quick actions above!',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: List.generate(logs.length, (i) {
            final log = logs[i];
            
            IconData icon = Icons.info_outline_rounded;
            Color iconColor = AppColors.indigo;
            String titleText = log.action;
            String subtitleText = 'Entity: ${log.entity}';

            if (log.action == 'AI_RESUME_PARSE_ENQUEUED') {
              icon = Icons.cloud_upload_rounded;
              iconColor = Colors.orange;
              final rawUrl = log.meta?['resumeFileUrl']?.toString() ?? '';
              final fileName = rawUrl.isNotEmpty ? rawUrl.split('/').last : 'resume';
              titleText = 'AI Resume Parse Enqueued';
              subtitleText = 'Processing file: $fileName';
            } else if (log.action == 'AI_RESUME_PARSE_PROCESSED') {
              icon = Icons.auto_awesome_rounded;
              iconColor = Colors.green;
              titleText = 'AI Resume Parsing Completed';
              subtitleText = 'Successfully parsed candidate details and saved profile.';
            } else if (log.action == 'JOB_CREATED') {
              icon = Icons.work_outline_rounded;
              iconColor = Colors.teal;
              final title = log.meta?['title']?.toString() ?? 'Job';
              titleText = 'New Job Posting Created';
              subtitleText = 'Job: $title';
            } else if (log.action == 'CANDIDATE_CREATED') {
              icon = Icons.person_add_rounded;
              iconColor = Colors.blue;
              final name = log.meta?['name']?.toString() ?? 'Candidate';
              titleText = 'Candidate Created Manually';
              subtitleText = 'Name: $name';
            } else if (log.action == 'CANDIDATE_APPLIED') {
              icon = Icons.assignment_turned_in_rounded;
              iconColor = Colors.cyan;
              final candidateName = log.meta?['candidateName']?.toString() ?? 'A candidate';
              final jobTitle = log.meta?['jobTitle']?.toString() ?? 'Job';
              titleText = 'New Job Application Received';
              subtitleText = '$candidateName applied for "$jobTitle"';
            }

            final timeString = _formatTimeAgo(log.createdAt);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                onTap: log.entityId != null && log.entity == 'candidate'
                    ? () => context.push('/candidates/${log.entityId}')
                    : null,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: iconColor.withValues(alpha: 0.12),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitleText,
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeString,
                          style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: cs.error.withValues(alpha: 0.7)),
                          tooltip: 'Delete activity',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Activity'),
                                content: const Text('Are you sure you want to delete this activity log?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('No'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: cs.error,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              try {
                                await ref.read(dashboardRepositoryProvider).deleteAuditLog(log.id);
                                ref.invalidate(dashboardActivityProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to delete: $e')),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: (40 * i).ms).slideY(begin: 0.04, curve: Curves.easeOutCubic);
          }),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime.toLocal());
    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

class _DeleteAllActivitiesButton extends ConsumerWidget {
  const _DeleteAllActivitiesButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(dashboardActivityProvider);
    final cs = Theme.of(context).colorScheme;

    return activityAsync.when(
      data: (logs) {
        if (logs.isEmpty) return const SizedBox.shrink();
        return TextButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Clear All Activities'),
                content: const Text('Are you sure you want to delete all activity logs? This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                    ),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              final savedLogs = List<AuditLog>.from(logs);
              try {
                await ref.read(dashboardRepositoryProvider).deleteAllAuditLogs();
                ref.invalidate(dashboardActivityProvider);
                
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('all files cleared'),
                    duration: const Duration(milliseconds: 4000),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () async {
                        try {
                          await ref.read(dashboardRepositoryProvider).restoreAuditLogs(savedLogs);
                          ref.invalidate(dashboardActivityProvider);
                        } catch (err) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed to restore: $err')),
                          );
                        }
                      },
                    ),
                  ),
                );

                Timer(const Duration(milliseconds: 2200), () {
                  messenger.clearSnackBars();
                });
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to clear activities: $e')),
                );
              }
            }
          },
          icon: Icon(Icons.delete_sweep_rounded, size: 18, color: cs.error),
          label: Text('Clear All', style: TextStyle(color: cs.error, fontWeight: FontWeight.bold)),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const ShimmerBlock(height: 36, width: 36, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBlock(height: 12, width: double.infinity, radius: 8),
                      SizedBox(height: 8),
                      ShimmerBlock(height: 10, width: 160, radius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const ShimmerBlock(height: 18, width: 54, radius: 10),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (60 * i).ms).slideY(begin: 0.04, curve: Curves.easeOutCubic);
      }),
    );
  }
}

Future<void> _openResumeParseDialog(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(candidatesRepositoryProvider);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      var isSubmitting = false;
      PlatformFile? selectedFile;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickFile() async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf'],
              withData: true,
            );
            if (result != null) {
              setDialogState(() {
                selectedFile = result.files.first;
              });
            }
          }

          Future<void> submit() async {
            if (isSubmitting) return;
            if (selectedFile == null || selectedFile!.bytes == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a PDF resume file')),
              );
              return;
            }
            setDialogState(() => isSubmitting = true);
            try {
              final url = await repo.uploadResume(
                fileName: selectedFile!.name,
                fileBytes: selectedFile!.bytes!,
              );

              final queueJobId = await repo.enqueueResumeParse(
                resumeFileUrl: url,
              );

              if (!context.mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Uploaded & queued parse (job $queueJobId). Refreshing...')),
              );
              
              ref.invalidate(dashboardActivityProvider);
              ref.invalidate(candidatesFeedProvider);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Processing failed: $e')),
              );
            } finally {
              if (dialogContext.mounted) setDialogState(() => isSubmitting = false);
            }
          }

          final cs = Theme.of(context).colorScheme;

          return AlertDialog(
            title: const Text('Parse resume (AI)'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: isSubmitting ? null : pickFile,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.14),
                      ),
                      child: selectedFile == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.picture_as_pdf_rounded, size: 36, color: cs.primary),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Select PDF resume file',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedFile!.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${(selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting || selectedFile == null ? null : submit,
                child: isSubmitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Queue'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _FunnelCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final funnelAsync = ref.watch(dashboardFunnelProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return funnelAsync.when(
      loading: () => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(6, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const ShimmerBlock(height: 16, width: 80, radius: 8),
                const SizedBox(width: 12),
                Expanded(child: const ShimmerBlock(height: 10, width: double.infinity, radius: 8)),
              ],
            ),
          )),
        ),
      ),
      error: (err, _) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Text('Failed to load funnel chart: $err'),
      ),
      data: (funnel) {
        final stages = ['APPLIED', 'PARSED', 'SCREENED', 'INTERVIEW', 'OFFER', 'HIRED', 'REJECTED'];
        final maxCount = funnel.values.fold<int>(0, (prev, element) => element > prev ? element : prev);
        
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(stages.length, (i) {
              final stage = stages[i];
              final count = funnel[stage] ?? 0;
              final pct = maxCount > 0 ? count / maxCount : 0.0;
              
              final gradient = _getFunnelGradient(stage);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatStageName(stage),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '$count',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 10,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.12),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: pct > 0 ? pct : 0.02,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: gradient,
                              boxShadow: [
                                BoxShadow(
                                  color: gradient.colors.first.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  LinearGradient _getFunnelGradient(String stage) {
    switch (stage) {
      case 'APPLIED':
        return const LinearGradient(colors: [AppColors.indigo, AppColors.cyan]);
      case 'PARSED':
        return const LinearGradient(colors: [Colors.purple, Colors.deepPurple]);
      case 'SCREENED':
        return const LinearGradient(colors: [AppColors.cyan, Colors.teal]);
      case 'INTERVIEW':
        return const LinearGradient(colors: [Colors.teal, Colors.green]);
      case 'OFFER':
        return const LinearGradient(colors: [Colors.green, Colors.orange]);
      case 'HIRED':
        return const LinearGradient(colors: [Colors.orange, Colors.pink]);
      default:
        return const LinearGradient(colors: [Colors.grey, Colors.blueGrey]);
    }
  }

  String _formatStageName(String stage) {
    switch (stage) {
      case 'APPLIED':
        return 'Applied';
      case 'PARSED':
        return 'AI Parsed';
      case 'SCREENED':
        return 'Screened';
      case 'INTERVIEW':
        return 'Interview';
      case 'OFFER':
        return 'Offer';
      case 'HIRED':
        return 'Hired';
      case 'REJECTED':
        return 'Rejected';
      default:
        return stage;
    }
  }
}

class _TimelineCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(dashboardTimelineProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return timelineAsync.when(
      loading: () => const GlassCard(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Text('Failed to load activity trend: $err'),
      ),
      data: (timeline) {
        if (timeline.isEmpty) {
          return const GlassCard(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              height: 100,
              child: Center(child: Text('No activity logs found')),
            ),
          );
        }

        final spots = <FlSpot>[];
        var maxVal = 0.0;
        for (var i = 0; i < timeline.length; i++) {
          final count = timeline[i].count.toDouble();
          spots.add(FlSpot(i.toDouble(), count));
          if (count > maxVal) maxVal = count;
        }

        if (maxVal == 0) maxVal = 5.0;
        final maxY = maxVal + 1.0;

        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Candidates Added (Last 14 Days)',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (value, meta) {
                            if (value == value.roundToDouble() && value % 2 == 0) {
                              return Text(
                                '${value.toInt()}',
                                style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < timeline.length && idx % 3 == 0) {
                              final rawDate = timeline[idx].date;
                              final date = DateTime.tryParse(rawDate);
                              final formatted = date != null ? DateFormat('MM/dd').format(date) : '';
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  formatted,
                                  style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (timeline.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        color: AppColors.cyan,
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.cyan.withValues(alpha: 0.3),
                              AppColors.cyan.withValues(alpha: 0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 3,
                            color: AppColors.cyan,
                            strokeWidth: 1.5,
                            strokeColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardFiltersRow extends ConsumerWidget {
  const _DashboardFiltersRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final jobsAsync = ref.watch(jobsFeedProvider);
    final filters = ref.watch(dashboardFiltersProvider);

    String formatDate(DateTime? d) {
      if (d == null) return 'All time';
      return DateFormat('MM/dd/yyyy').format(d);
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_rounded, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Filter Dashboard',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (filters.jobId != null || filters.startDate != null || filters.endDate != null)
                TextButton(
                  onPressed: () {
                    ref.read(dashboardFiltersProvider.notifier).reset();
                  },
                  child: const Text('Reset'),
                ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: jobsAsync.when(
                  data: (jobs) => DropdownButtonFormField<String?>(
                    value: filters.jobId,
                    decoration: const InputDecoration(
                      labelText: 'Job Posting',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Jobs')),
                      ...jobs.map((j) => DropdownMenuItem(value: j.id, child: Text(j.title, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) {
                      ref.read(dashboardFiltersProvider.notifier).setJobId(val);
                    },
                  ),
                  loading: () => const ShimmerBlock(height: 48, width: double.infinity, radius: 8),
                  error: (_, __) => DropdownButtonFormField<String?>(
                    value: null,
                    decoration: const InputDecoration(
                      labelText: 'Job Posting',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: const [DropdownMenuItem(value: null, child: Text('Failed to load jobs'))],
                    onChanged: (_) {},
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      initialDateRange: filters.startDate != null && filters.endDate != null
                          ? DateTimeRange(start: filters.startDate!, end: filters.endDate!)
                          : null,
                    );
                    if (range != null) {
                      ref.read(dashboardFiltersProvider.notifier).setDateRange(range.start, range.end);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            filters.startDate == null ? 'Select dates' : '${formatDate(filters.startDate)} - ${formatDate(filters.endDate)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: filters.startDate == null ? theme.hintColor : theme.textTheme.bodyMedium?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.calendar_today_rounded, size: 16, color: cs.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

